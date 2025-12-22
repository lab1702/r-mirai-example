# Shiny + mirai example: Single daemon processing long-running queries
# Multiple users can submit queries; they queue and run one at a time
# Any query that has been run before is cached on disk for fast retrieval

library(shiny)
library(bslib)
library(mirai)

# Start a single daemon - all tasks will queue through this one worker
message("Starting Mirai daemons(1)")
daemons(n = 1)

# Cleanup daemon on app exit
onStop(function() {
  message("Stopping Mirai daemons(0)")
  daemons(0)
})

# Configure daemon workers with duckdb and memoisation
# Note: Code inside everywhere() runs on daemon workers, not the main process
message("Configuring all Mirai daemons")
everywhere({
  library(DBI)
  library(duckdb)
  library(memoise)

  # Using <<- to assign to daemon's global environment so functions persist
  get_duckdb_func <<- function(sql, params = list()) {
    con <- dbConnect(duckdb::duckdb())
    on.exit(dbDisconnect(con))

    dbGetQuery(conn = con, statement = sql, params = params)
  }

  # Memoise with disk cache in /tmp/get_duckdb_cache
  get_duckdb <<- memoise(
    f = get_duckdb_func,
    cache = cachem::cache_disk(dir = "/tmp/get_duckdb_cache")
  )
})

ui <- page_navbar(
  theme = bs_theme(preset = "bootstrap"),
  title = "Mirai Demo",
  sidebar = sidebar(
    input_task_button(
      id = "submit",
      label = "Submit Query"
    )
  ),
  nav_panel(
    "Main",
    card(
      card_header("Result"),
      verbatimTextOutput("result")
    ),
  ),
  nav_spacer(),
  nav_item(textOutput("mirai_status")),
  nav_item(input_dark_mode())
)

server <- function(input, output, session) {
  # Define mirai task to run SQL queries using duckdb
  query_task <- ExtendedTask$new(function(sql, params = list()) {
    mirai(
      {
        get_duckdb(sql = sql, params = params)
      },
      sql = sql,
      params = params
    )
  }) |> bind_task_button("submit")

  # Submit example slow query when button clicked
  observeEvent(input$submit, {
    message("Button Clicked")
    query_task$invoke(
      "SELECT count(*) AS test_count FROM range(1000000000) t1, range(100) t2;"
    )
  })

  # Show current status of mirai daemons
  output$mirai_status <- renderText({
    invalidateLater(500)

    a <- status()

    sprintf(
      "Queries: %d waiting, %d running",
      a$mirai[1],
      a$mirai[2]
    )
  })

  # Show result when complete
  output$result <- renderPrint({
    req(result <- query_task$result())

    message("Displaying Results")
    result
  })
}

shinyApp(ui, server)

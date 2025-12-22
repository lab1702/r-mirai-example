# Shiny + mirai example: Queue multiple queries from a single button click
# Uses mirai_map() to batch 3 queries; they queue and run one at a time
# Results stored in reactiveVal and displayed in separate outputs
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

  # Memoise to cache query results in daemon memory
  get_duckdb <<- memoise(get_duckdb_func)
})

ui <- page_navbar(
  theme = bs_theme(preset = "bootstrap"),
  title = "Mirai Demo",
  sidebar = sidebar(
    input_task_button(
      id = "submit",
      label = "Submit 3 Queries"
    )
  ),
  nav_panel(
    "Main",
    card(
      card_header("Query 1 Result"),
      verbatimTextOutput("result1")
    ),
    card(
      card_header("Query 2 Result"),
      verbatimTextOutput("result2")
    ),
    card(
      card_header("Query 3 Result"),
      verbatimTextOutput("result3")
    ),
  ),
  nav_spacer(),
  nav_item(textOutput("mirai_status")),
  nav_item(input_dark_mode())
)

server <- function(input, output, session) {
  # Store results from all queries
  all_results <- reactiveVal(NULL)

  # Watch for cache clear signal file
  observe({
    invalidateLater(1000)

    if (file.exists("/tmp/clear_duckdb_cache_signal")) {
      message("Cache clear signal detected - clearing cache")
      mirai({
        memoise::forget(get_duckdb)
      })
      file.remove("/tmp/clear_duckdb_cache_signal")
    }
  })

  # Define mirai task to run multiple SQL queries using mirai_map
  query_task <- ExtendedTask$new(function(queries) {
    mirai_map(.x = queries, .f = function(sql) get_duckdb(sql))
  }) |> bind_task_button("submit")

  # Submit 3 queries on button click
  observeEvent(input$submit, {
    message("Button Clicked - Submitting 3 queries")
    all_results(NULL) # Clear previous results
    query_task$invoke(list(
      "SELECT 'Q1' AS q, count(*) AS c FROM range(1000000000) t1, range(100) t2;",
      "SELECT 'Q2' AS q, count(*) AS c FROM range(1000000000) t3, range(100) t4;",
      "SELECT 'Q3' AS q, count(*) AS c FROM range(1000000000) t5, range(100) t6;"
    ))
  })

  # Show current status of mirai daemons
  output$mirai_status <- renderText({
    invalidateLater(1000)

    a <- status()

    sprintf(
      "Queries: %d waiting, %d running",
      a$mirai[1],
      a$mirai[2]
    )
  })

  # Store results when all queries complete
  observe({
    req(results <- query_task$result())
    message("All queries complete")
    all_results(results)
  })

  # Each output pulls its specific result
  output$result1 <- renderPrint({
    req(all_results())
    all_results()[[1]]
  })

  output$result2 <- renderPrint({
    req(all_results())
    all_results()[[2]]
  })

  output$result3 <- renderPrint({
    req(all_results())
    all_results()[[3]]
  })
}

shinyApp(ui, server)

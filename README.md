# r-mirai-example

A practical example demonstrating how to use the `mirai` package with Shiny to handle long-running queries without blocking the user interface.

## Overview

This project shows how to build a responsive Shiny application that processes multiple long-running database queries sequentially through a single worker daemon, while keeping the UI responsive and allowing users to see query queue status in real-time.

## Why Sequential Processing?

DuckDB queries can consume significant server resources by default:
- Each query can utilize **all available CPU cores** on the server
- Memory consumption can reach up to **80% of available memory** per query with default DuckDB configuration.

Running multiple queries concurrently would quickly exhaust server resources and degrade performance for all users. By processing queries sequentially through a single daemon, you ensure:
- Predictable resource consumption
- No resource contention between queries
- Server stability even under high load
- Consistent performance for all users

## Key Features

- **Non-blocking UI**: Long-running queries don't freeze the application interface
- **Query Queuing**: Multiple queries are automatically queued and processed sequentially
- **Result Caching**: Repeated queries are cached on disk using `memoise` for instant retrieval
- **Real-time Status**: Display current number of waiting and running queries
- **DuckDB Integration**: Uses DuckDB for efficient in-memory SQL query execution
- **Dark Mode Support**: Built-in theme switching with `bslib`

## Project Structure

- `small_shiny_mirai_test.R`: Main application file containing the Shiny UI and server logic
- `README.md`: This documentation file
- `LICENSE`: Project license

## How It Works

1. **Mirai Daemon Setup**: A single Mirai daemon is initialized to process all incoming tasks sequentially
2. **Task Queue**: When users submit queries, they are added to a queue in the daemon
3. **Memoization**: Results are cached using `memoise` with a disk-based cache in `/tmp/get_duckdb_cache`
4. **Status Updates**: The UI polls the daemon status every 1000ms to display waiting and running query counts
5. **Result Display**: When a query completes, results are automatically displayed in the UI

## Example Workflow

The application submits 3 test queries that count combinations from large ranges:
```sql
SELECT 'Q1' AS q, count(*) AS c FROM range(1000000000) t1, range(100) t2;
SELECT 'Q2' AS q, count(*) AS c FROM range(1000000000) t3, range(100) t4;
SELECT 'Q3' AS q, count(*) AS c FROM range(1000000000) t5, range(100) t6;
```

When you click "Submit 3 Queries", the application:
- Batches all 3 queries using `mirai_map()` and queues them to the daemon
- Continues to respond to user interactions
- Shows how many queries are waiting/running
- Displays each result in its own card when complete
- Caches each result for subsequent requests

## Requirements

- R (3.6+)
- shiny
- mirai
- bslib
- DBI
- duckdb
- memoise
- cachem

## Running the Application

```R
Rscript small_shiny_mirai_test.R
```

The application will start and automatically clean up the Mirai daemon when closed.

## Use Cases

This pattern is ideal for:
- Web applications with computationally expensive queries
- Data processing pipelines requiring sequential execution
- Multi-user systems where server resources need optimization
- Applications requiring responsive UIs despite backend processing delays

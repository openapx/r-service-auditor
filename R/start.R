#' Start auditor service
#' 
#' @param port Service port
#' 
#' 
#' @description
#' A standard configurable start for plumber.
#' 
#' The function searches for `plumber.R` in the following directories
#' \itemize{
#'   \item current working directory
#'   \item directory `inst/ws` in the current working directory (development mode)
#'   \item directory `ws` in the current working directory (installed)
#'   \item directory `ws` in the first occurrence of `auditor.service` in the library tree
#' }
#'  ws directory starting with
#' the current working directory and then package install locations in
#' \code{.libPaths()}.
#' 
#' The following app properties are used for database connections.
#' \itemize{
#'   \item `DB.VENDOR` (future) to support vendor specific SQL syntax and optimizations
#'   \item `DB.DRIVER` Database driver (DBI compatible)
#'   \item `DB.DATABASE` Database name 
#'   \item `DB.HOST` Database host (defaults to `localhost`)
#'   \item `DB.PORT` Database port
#'   \item `DB.USERNAME` Database username or account
#'   \item `DB.PASSWORD` Database username or account password
#'   \item `DB.POOL.MINSIZE` Minimum connections in database pool
#'   \item `DB.POOL.MAXSIZE` Maximum connections in database pool
#'   \item `DB.POOL.IDLETIMEOUT` Idle duration in seconds until dropping idle connections
#'                               beyond the pool's minimum number of connections
#' }
#' 
#' Note that the above configuration uses \link[cxapp]{cxapp_config} and supports
#' both environmental variables and key vaults.
#' 
#' For further details on `DB.POOL.MINSIZE`, `DB.POOL.MAXSIZE` and `DB.POOL.IDLETIMEOUT`, 
#' see \link[pool]{poolCreate}.
#' 
#' 
#' 
#' @export 

start <- function( port = 12345 ) {
  
  # -- load configuration
  cfg <- cxapp::.cxappconfig()
  
  
  # -- set up database pool

  db_required_cfg <- c( "db.vendor", "db.driver", "db.host", "db.port", "db.username", "db.password" )  
  
  for ( xopt in db_required_cfg )
    if ( is.na( cfg$option( xopt, unset = NA ) ) ) {
      cxapp::cxapp_log( paste( "Property", base::toupper(xopt), "required and not defined" ) )
      stop(paste( "Property", base::toupper(xopt), "required and not defined" ))
    }


  # - remove existing pool  
  if ( base::exists( ".auditor.dbpool", envir = .GlobalEnv) )
    rm( list = ".auditor.dbpool", envir = .GlobalEnv )

  # - create pool
  assign( ".auditor.dbpool", 
          pool::dbPool( drv = eval(parse( text = cfg$option( "DB.DRIVER", unset = NA ))),
                        dbname = cfg$option( "DB.DATABASE", unset = "auditor" ),
                        host = cfg$option( "DB.HOST", unset = "localhost" ),
                        port = cfg$option( "DB.PORT", unset = NA ),
                        user = cfg$option( "DB.USERNAME", unset = "auditor" ),
                        password = cfg$option( "DB.PASSWORD", unset = paste( sample( c( base::letters, as.character(0:9) ), 
                                                                                     40, 
                                                                                     replace = TRUE ), 
                                                                             collapse = "") ),
                        minSize = cfg$option( "DB.POOL.MINSIZE", unset = 1),
                        maxSize = cfg$option( "DB.POOL.MAXSIZE", unset = 25),
                        idleTimeout = cfg$option( "DB.POOL.IDLETIMEOUT", unset = 120) ),
          envir = .GlobalEnv )

  cxapp::cxapp_log( paste( "Database pool started with",
                           cfg$option( "DB.POOL.MINSIZE", unset = 1), "minimum and",
                           cfg$option( "DB.POOL.MAXSIZE", unset = 25), "maximum connections.") )
  
  # - add routine to close connection pool on exit

  on.exit( {
    
    if ( base::exists( ".auditor.dbpool", envir = .GlobalEnv) ) {
      pool::poolClose( base::get(".auditor.dbpool", envir = .GlobalEnv)  )
      cxapp::cxapp_log( "Database pool closed" )
      rm( list = ".auditor.dbpool", envir = .GlobalEnv )
    }

  }, add = TRUE)
  

  
  # -- set up search locations for the plumber
  # note: start looking in ws under working directory and then go looking in .libPaths()
  xpaths <- c( file.path(getwd(), "plumber.R"),
               file.path(getwd(), "inst", "ws", "plumber.R"),
               file.path(getwd(), "ws", "plumber.R"),
               file.path( .libPaths(), "auditor.service", "ws", "plumber.R" ) )
  
  # -- firs one will do nicely  
  xplumb <- utils::head( xpaths[ file.exists(xpaths) ], n = 1 )
  
  if ( length( xplumb ) == 0 )
    stop( "Could not find plumber.R file " )
  
  # -- start ... defaults for now
  api <- plumber::pr( xplumb )
  
  plumber::pr_run( api, 
                   port = Sys.getenv("API_PORT", unset = port ), 
                   quiet = TRUE )
  
  
  
  # -- close database pool
  
  # -- remove existing pool  
  
  
}
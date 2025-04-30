#' List audit records
#' 
#' @param x List representing a filter for records
#' @param connection DBI database connection
#' 
#' @return A list of records
#' 
#' 
#' @export



auditor_list <- function(x, connection = NULL ) {
  
  
  # -- default filter 
  #    note: all filters are assumed meaning "and"
  
  rec_filter <- list( "events" = NULL, 
                      "types" = NULL,
                      "classes" = NULL,
                      "references" = NULL,
                      "objects" = NULL, 
                      "actors" = NULL, 
                      "to" = base::format( base::as.POSIXct( Sys.time(), tz = "UTC"), format = "%Y-%m-%d %H:%M:%S"), 
                      "from" = base::format( base::as.POSIXct( Sys.Date() - 30, tz = "UTC"), format = "%Y-%m-%d %H:%M:%S"),
                      "limit" = 300, 
                      "offset" = NULL )

  
  # -- identify submitted filter
  
  if ( ! missing(x) && ! is.null(x) && ! any(is.na(x)) )
    for ( xitem in base::tolower(base::trimws(names(x))) )
      if ( xitem %in% names(rec_filter) )
        rec_filter[[ xitem ]] <- base::tolower(base::trimws(x[[xitem]]))
  
    
  
  # -- assemble SQL filter
  
  sql_whr <- character(0)
  
  
  col_map <- c( "events" = "str_event", "types" = "str_type", "classes" = "str_class", "references" = "str_ref", "objects" = "str_objecthash", "actors" = "str_actor" )
  
  for ( xitem in c( "events", "types", "classes", "references", "objects", "actors" ) ) 
    if ( xitem %in% base::tolower(names(rec_filter)) && ! is.null(rec_filter[[xitem]]) && (length(rec_filter[[xitem]]) > 0) )  {
      
      if ( length(rec_filter[[xitem]]) == 1 ) {
        sql_whr <- append( sql_whr, 
                           paste( col_map[xitem], "=", base::sQuote( base::tolower(base::trimws(rec_filter[[xitem]])), q = FALSE) ) )
        
        next()
      }
      
      sql_whr <- append( sql_whr, 
                         paste( col_map[xitem], "in (", paste( base::sQuote( base::tolower(base::trimws(rec_filter[[xitem]])), q = FALSE), collapse = "," ), ")", sep = " " ) )
  
    }
  

  if ( ! is.null(rec_filter[["from"]]) ) 
    sql_whr <- append( sql_whr, 
                       paste( "ts_datetime >=", base::sQuote(base::trimws( rec_filter[["from"]]), q = FALSE), sep = " " ) )
  
  
  if ( ! is.null(rec_filter[["to"]]) ) 
    sql_whr <- append( sql_whr, 
                       paste( "ts_datetime <=", base::sQuote(base::trimws( rec_filter[["to"]]), q = FALSE), sep = " " ) )
  
  
  
  # -- assemble SQL query
  
  sql <- "select cast(uid as varchar(128)), str_event, str_type, str_class, str_ref, str_objecthash, str_label, str_actor, ts_datetime from tbl_adt_records"
  
  if ( length( sql_whr ) > 0 ) 
    sql <- append( sql, c( "where (", 
                           paste( paste( "(", sql_whr, ")" ), collapse = " and " ),
                           ")"  ) 
                 )
  
  if ( "limit" %in% names(rec_filter) && ! is.null(rec_filter[["limit"]])  )
    sql <- append( sql,
                   paste( "limit", as.character(rec_filter[["limit"]]), sep = " ") )
  
  if ( "offset" %in% names(rec_filter) && ! is.null(rec_filter[["offset"]]) )
    sql <- append( sql,
                   paste( "offset", as.character(rec_filter[["offset"]]), sep = " ") )
  
  


  # -- query database
    
  db_qry <- try( DBI::dbGetQuery( connection, paste( c( sql, ";"), collapse = " " ) ), silent = TRUE )

  if ( inherits( db_qry, "try-error" ) || ( nrow(db_qry) == 0 ) )
    return(invisible( list() ))

  
  # -- convert returned dataframe to list
  
  lst <- list()

  
  for ( idx in 1:nrow(db_qry) ) {
    
    rec <- as.list(db_qry[ idx, ])
    names(rec) <- c( "id", "event", "type", "class", "reference", "object", "label", "actor", "datetime" )
    
    
    rec[["datetime"]] <- format( as.POSIXct( rec[["datetime"]], tz = "UTC"), format = "%Y%m%dT%H%M%S" )
    
    lst[[ length(lst) + 1 ]] <- rec  
    
    rm(rec)
  }
  
  

  return( invisible(lst) )
}

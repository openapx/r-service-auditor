#' Get audit record
#' 
#' @param x Record identifier
#' @param connection DBI connection
#' 
#' @return List containing the audit record
#' 
#' @description
#' The returned list of named elements consists of three main parts. The main 
#' audit record, the record attributes and lastly links to other audit records. 
#' 
#' The named element `id` refers to the audit record identifier. A record
#' attribute does not have an associated attribute identifier, but is referred
#' to by its key. Key values are not unique within the list of attributes and 
#' serves only as a programmatic identifier.
#' 
#' Attributes are returned in natural sort order of the value for `key`.
#' 
#' @export

auditor_record <- function( x, connection = NULL ) {

  # -- obviously no matching record
  if ( missing(x) || is.null(x) || any(is.na(x)) || ! inherits( x, "character") || (length(x) != 1) || ! uuid::UUIDvalidate(x) )
    return(invisible(list()))
    
  
  # -- get main record
  
  sql <-  paste( c( "select cast(uid as varchar(128)), str_event, str_type, str_class, str_ref, str_objecthash, str_label, str_actor, str_env, ts_datetime from tbl_adt_records",
                    "where (", 
                    paste( "uid = ", base::sQuote(base::trimws(x), q = FALSE) ), 
                    ") ;" ), collapse = " " )
  
  
  rslt_rec <- try( DBI::dbGetQuery( connection, sql ), silent = FALSE )
  
  if ( inherits( rslt_rec, "try-error" ) || (nrow(rslt_rec) == 0) )
    return(invisible( list() ))


  # -- initialize return
  lst <- as.list( rslt_rec[1,] )
  names(lst) <- c( "id", "event", "type", "class", "reference", "object", "label", "actor", "env", "datetime" )
  
  # - update date/time format
  lst[["datetime"]] <- format( as.POSIXct( lst[["datetime"]], tz = "UTC"), format = "%Y%m%dT%H%M%S" )
  
  
  # - initiate attributes and links
  lst[["attributes"]] <- list()
  lst[["links"]] <- list()
  

  
  
  # -- get attributes
 
  sql_attr <-  paste( c( "select str_key, str_label, str_qual, str_value, int_vseq from tbl_adt_record_attrs", 
                         paste( "where ( uid_rec = ", base::sQuote(base::trimws(x), q = FALSE), ")", sep = " " ), 
                         "order by str_key, int_vseq desc ;" ), collapse = " " )
  

  
  rslt_attr <- try( DBI::dbGetQuery( connection, sql_attr ), silent = FALSE )
  
  if ( ! inherits( rslt_attr, "try-error" ) && (nrow(rslt_attr) > 0) ) {

    lst_attr <- list()
    
    rec_attr <- list()  # initialize empty for first use
    
    for ( idx in 1:nrow(rslt_attr) ) {

      # -- get main attribute record part
      rec_attr_row <- as.list(rslt_attr[ idx, ])
      names(rec_attr_row) <- c( "key", "label", "qualifier", "value", "internal_vseq" )

      if ( length(rec_attr) == 0 ) 
        rec_attr <- rec_attr_row[ c( "key", "label", "qualifier", "value") ]

      
      if ( rec_attr_row[["internal_vseq"]] == 0 )  {
        lst_attr[[ length(lst_attr) + 1 ]] <- rec_attr
        rec_attr <- list()
        next()
      }
      
      # note: DESC in order by clause is last value chunk to first value chunk
      rec_attr[[ "value" ]] <- paste( rec_attr_row[["value"]], rec_attr[["value"]], sep = "" )

    }  # end of for-statement across attribute records
    
    
    lst[["attributes"]] <- lst_attr    
    
  }  # end of if-statement with record attributes

  
  # -- get links
  
  sql_links <- paste( c( "select cast(uid as varchar(128)), str_event, str_type, str_class, str_ref, str_objecthash, str_label from tbl_adt_records", 
                         "where ", 
                         "    ( uid in ( select distinct uid_rec from tbl_adt_record_links where ", 
                         paste( "        uid in ( select distinct uid from tbl_adt_record_links where ( uid_rec =", base::sQuote( base::trimws(x), q = FALSE ), " ) )", sep = " "),
                         "             ) ) and",
                         paste( "( uid <>", base::sQuote( base::trimws(x), q = FALSE ), ")" ) )
                      , collapse = " " )
  
  rslt_links <- try( DBI::dbGetQuery( connection, sql_links ), silent = FALSE )
  
  if ( ! inherits( rslt_links, "try-error" ) && (nrow(rslt_links) > 0) ) {
    
    for ( idx in 1:nrow(rslt_links) ) {
      
      rec_links <- as.list(rslt_links[ idx, ])
      names(rec_links) <- c( "id", "event", "type", "class", "reference", "object", "label" )
      
      lst[["links"]][[ length(lst[["links"]]) + 1 ]] <- rec_links
      
      rm(rec_links)
    }
    
  } # end of if-statement with record links
    

  
  return(invisible(lst))
}

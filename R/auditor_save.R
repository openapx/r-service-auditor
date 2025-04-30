#' Utility function to save one or more records 
#' 
#' @param x List of records
#' @param connection DBI database connection
#' 
#' @return Logical if the records were created
#' 
#' @description
#' This utility function will save an audit record along with its attributes.
#' 
#' A record is defined by a set of standard notations.
#' \itemize{
#'   \item `event` the audit event
#'   \item `type` the type of audited object
#'   \item `class` optional reference to a class of object type
#'   \item `reference` reference to the object
#'   \item `object` optional hash representing the object regardless of context
#'   \item `label` short human readable description of the event 
#'   \item `actor` user or service that initiated/triggered the event
#'   \item `attributes` a list of attributes associated with the event
#' }
#' 
#' The `event` is one of the case in-sensitive values `create`, `read`, `update`,
#' `delete`, `execute`, `sign`, `connect` or `disconnect`.
#' 
#' If `class` is not specified for an audited event, the value of `type` is used.
#' 
#' If `object` is omitted, the object hash is derived based on the specified `type`, 
#' `class` and `reference`. 
#' 
#' `attributes` is a list of qualified key/value pairs. An attribute is defined
#' as 
#' \itemize{
#'   \item `key` attribute name represented as a keyword
#'   \item `label` short human readable label of the key
#'   \item `qual` or `qualifier` that provide context to the value
#'   \item `value` the attribute value
#' }
#' 
#' The `label` and `value` values are stored URL encoded.
#'  
#' If the audit event record property, say the audit record `label`, is longer 
#' than the property storage length, the property value is truncated in the main
#' record and the original value recorded as a record attribute with the `key` 
#' equal to the propery name, the attribute `label` equal to 
#' `<property> original value`, `qualifier` equal to `original_value` and 
#' attribute `value` equal to the original property value.
#' 
#' If more than one record is submitted, the individual audit records are linked.
#' 
#' 
#' 
#' @export


auditor_save <- function( x, connection = NULL ) {

  if ( missing(x) || is.null(x) || any(is.na(x)) || ! inherits( x, "list" ) )
    stop( "Audit record missing or invalid" )
  
  
  # -- obviously 
  if (length(x) == 0 )
    return(invisible(TRUE))

  
  # -- some constants 
  supported_events <- c( "CREATE", "READ", "UPDATE", "DELETE", "EXECUTE", "SIGN", "CONNECT", "DISCONNECT" )

  attr_maxlengths <- c( "event" = 50, "type" = 100, "reference" = 2048, "object" = 128, "label" = 512, "actor" = 512, 
                        "attr.key" = 1024, "attr.label" = 512, "attr.qual" = 50, "attr.qualifier" = 50, "attr.value" = 1024  )
  

  
  # -- record timestamp value
  #    note: already quoted
  rec_q_timestamp <- base::sQuote( base::format( base::as.POSIXct( Sys.time(), tz = "UTC"), format = "%Y-%m-%d %H:%M:%S"), q = FALSE )
  
    
  # -- create record structure
  sql_rec <- c( "insert into tbl_adt_records", 
                "( uid, str_event, str_type, str_class, str_ref, str_objecthash, str_label, str_actor, ts_datetime )", 
                "values" )
  
  sql_rec_attrvalues <- c( "insert into tbl_adt_record_attrs", 
                           "( uid_rec, str_key, str_label, str_qual, str_value, int_vseq )", 
                           "values" )
  

  
  sql_rec_links <- c( "insert into tbl_adt_record_links", 
                      "( uid, uid_rec )", 
                      "values" )
  

  
  
  # -- list of insert value rows
  #    note: strategy is to set up insert rows in a vector and then collapse it into the SQL insert statement
  
  # - list of record rows
  lst_rec <- character(0)
  
  
  # - list of attribute record rows
  lst_rec_attr <- character(0)

  
  # - list linked records
  lst_linked <- character(0)
  
  
  
  
  for ( xidx in 1:length(x) ) {
    
    # - standard view of record
    xrec <- x[[ xidx ]]
    names(xrec) <- base::tolower(base::names(xrec))


    # - initialize attribute list
    #   note: used to store long values
    rec_attr <- list()
    
    if ( "attributes" %in% names(xrec) )
      rec_attr <- xrec[["attributes"]]
    
    # - unique record identifier
    uid_rec <- uuid::UUIDgenerate() 
    
    
    # - trap record issues 
    #   note: this should be done better with record dump
    if ( ! all(c( "event", "type", "reference", "label", "actor" ) %in% base::tolower(base::names(xrec)) ) )
      stop( "Audit record ", as.character(xidx), " incomplete" )
    
    if ( ! base::toupper(xrec[["event"]]) %in% supported_events )
      stop( "Audit record ", as.character(xidx), " event ", base::toupper(xrec[["event"]]), " invalid" )

    
    
    # - default references in record
    
    if ( ! "class" %in% names(xrec) )
      xrec[["class"]] <- xrec[["type"]]

    if ( ! "object" %in% names(xrec) )
      xrec[["object"]] <- digest::digest( paste( "arn", "object", xrec[["type"]], xrec[["class"]], xrec[["reference"]], collapse = ":" ), algo = "sha1", file = FALSE )
    
    
    
    # - generate SQL 
    #   note: sequence uid, str_event, str_type, str_class, str_objecthash, str_label, str_actor, ts_date
    #   note: verify with above
    
    rec_obs <- c( base::sQuote( uid_rec, q = FALSE ) ) 
                  
    for ( xitem in c( "event", "type", "class", "reference", "object", "label", "actor" ) ) {
      
      xitem_val <- base::trimws(xrec[[ xitem ]] )

      if ( xitem == "label" )
        xitem_val <- utils::URLencode( base::trimws(xrec[[ xitem ]] ), reserved = TRUE )

      if ( xitem != "label" )
        xitem_val <- base::tolower(base::trimws(xrec[[ xitem ]] ))
      
      # - check for max value length
      if ( xitem %in% names(attr_maxlengths) && ( base::nchar(xitem_val) > attr_maxlengths[xitem] ) ) {
        

        # - add original value to record attributes        
        rec_attr[[ length(rec_attr) + 1 ]] <- list( "key" = xitem, 
                                                    "label" = utils::URLencode( paste( xitem, "original value"), reserved = TRUE),
                                                    "qual" = "original_value", 
                                                    "value" = xitem_val )
        
        
        # .. truncate value
        xitem_val <- base::substr( xitem_val, 1, attr_maxlengths[xitem] )

      }
      
      rec_obs <- append( rec_obs, base::sQuote( xitem_val, q = FALSE ) )
      
      base::rm(xitem_val)

    } #  end of for-statement for record values
    
    
    # - add timestamp
    rec_obs <- append( rec_obs, rec_q_timestamp )

    
    # - add insert value row
    lst_rec <- append(lst_rec, 
                      paste0( "(", paste( rec_obs, collapse = ", "), ")" ) )

    

    
    if ( length(rec_attr) > 0 )
      for ( xattr in rec_attr ) {
        
        if ( ! all( c("key", "value") %in% names(xattr) ) )
          stop( "Audit record ", as.character(xidx), " has an incomplete or invalid record attribute" )
        

        for ( xkey in c( "key", "label", "qual", "qualifier" ) )
          if ( xkey %in% names(xattr) && paste0( "attr.", xkey ) %in% names(attr_maxlengths) &&
               ( base::nchar(base::trimws( xattr[[xkey]] )) > attr_maxlengths[ paste0( "attr.", xkey ) ] ) )
            stop( "Audit record ", as.character(xidx), " attribute ", xkey, " length is too long" )


        qual <- ""
        
        if ( any( c("qual", "qualifier") %in% names(xattr) ) )
          qual <- base::trimws(utils::head(xattr[ c( "qual", "qualifies") ], n = 1))

        
        
        
        # -- chunk the value
        
        attr_value <- utils::URLencode( base::trimws(xattr[["value"]]), reserved = TRUE )

                
        if ( base::nchar(attr_value) > attr_maxlengths[ "attr.value" ] ) {
          
          attr_value_size <- base::nchar(attr_value)
          
          block_size <- attr_maxlengths[ "attr.value" ]
          
          blocks <- base::floor( attr_value_size / block_size )
          block_tail <- attr_value_size %% block_size
          

          value_blocks <- character(0)
          
          for ( idx_block in 1:blocks  )
            value_blocks <- append( value_blocks, base::substring( attr_value, (idx_block - 1)*block_size + 1, last = idx_block*block_size ) )
          
          if ( block_tail > 0 )
            value_blocks <- append( value_blocks, base::substring( attr_value, blocks*block_size + 1 ) )
          
          
          # - replace attr_value with vector of value blocks
          attr_value <- value_blocks
        }
        

        # - derive label if not defined
        xlabel <- base::trimws(xattr[["key"]])
        
        if ( "label" %in% names(xattr) )
          xlabel <- base::trimws(xattr[["label"]])

        xlabel <- utils::URLencode( xlabel, reserved = TRUE )
        
                
        # - generate SQL
        #   note: sequence uid_rec, str_key, str_label, str_qual, str_value, int_vseq
        #   note: verify above
        
        attrec_obs <- character(0)

        for ( idx_value in 1:length(attr_value) ) {
          
          rec_attr_obs <- c( base::sQuote( uid_rec, q = FALSE ),
                             base::sQuote( base::trimws(xattr[["key"]]), q = FALSE ),
                             base::sQuote( xlabel, q = FALSE ),
                             base::sQuote( qual, q = FALSE ), 
                             base::sQuote( attr_value[idx_value], q = FALSE ),
                             as.character(idx_value - 1) )  
        
          lst_rec_attr <- append( lst_rec_attr, 
                                  paste0( "(", paste( rec_attr_obs, collapse = ", "), ")" ) )
        
        }
        
      }  # end of for-statement across record attributes
    
    
    # - add record id to linked records
    lst_linked <- append(lst_linked, uid_rec )

  } # -- end of for-statement for each each audit record
  
  
  # - generate SQL for linked records
  #   note: sequence uid, uid_rec
  #   note: verify above
  
  lst_rec_links <- character(0)
  
  # - generate uid for linked records
  uid_link <- uuid::UUIDgenerate()
  

  for ( xlink in lst_linked )
    lst_rec_links <- append( lst_rec_links, 
                             paste0( "(", base::sQuote( uid_link, q = FALSE ), ", ", base::sQuote( xlink, q = FALSE), ")" ) )
    

  
 
  # -- SQL statements 

  sql <- as.character(rep_len( NA, 3 ))
  names(sql) <- c( "records", "attributes", "links" )
  
    
  # - amend record SQL statements
  
  sql["records"] <- paste( c( sql_rec, paste( lst_rec, collapse = ","), ";" ), collapse = " " )
  
  sql["attributes"] <- paste( c( sql_rec_attrvalues, paste( lst_rec_attr, collapse =  ","), ";" ), collapse = " " )
  
  sql["links"] <- paste( c( sql_rec_links, paste( lst_rec_links, collapse = ","), ";" ), collapse = " " )

  
  # -- save to database 

  dbupdates <- as.numeric( rep_len( NA, length(sql) ) )
  names(dbupdates) <- names(sql)
  
  
  if ( ! DBI::dbBegin( connection ) )  
    stop( "Could not start transaction" )

  for ( xcontext in c( "records", "attributes", "links") )  
    if ( ! is.na(sql[xcontext]) )
      dbupdates[ xcontext ] <- DBI::dbExecute( connection, sql[xcontext] )


  if ( ! DBI::dbCommit( connection ) )  {

    if ( ! DBI::dbRollback( connection ) )
      stop( "Could not commit transaction and rollback failed" )
    
    return(invisible(FALSE))
  }

  
  if ( ( length(lst_rec) != dbupdates[ "records" ] ) ||
       ( length(lst_rec_attr) != dbupdates[ "attributes" ] ) ||
       ( length(lst_rec_links) != dbupdates[ "links" ] ) )
    stop( "Not all audit records committed" )
  
   

  return(invisible(TRUE))
}

#
#
#
#
#


#* List audit records
#* 
#* @get /api/records
#* 
#* @response 200 OK
#* @response 400 Bad Request
#* @response 401 Unauthorized
#* @response 403 Forbidden
#* @response 500 Internal Server Error
#* 

function( req, res ) {
  
  # -- default attributes
  log_attributes <- c( base::toupper(req$REQUEST_METHOD), 
                       req$REMOTE_ADDR, 
                       req$PATH_INFO )
  
  
  # -- Authorization
  
  if ( ! "HTTP_AUTHORIZATION" %in% names(req) ) {
    cxapp::cxapp_log("Authorization header missing", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return(list( "error" = "Authorization header missing") )
  }
  
  
  auth_result <- try( cxapp::cxapp_authapi( req$HTTP_AUTHORIZATION ), silent = TRUE )
  
  if ( inherits( auth_result, "try-error" ) ) {
    cxapp::cxapp_log("Authorization failed", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return(list( "error" = "Authorization failed"))
  }
  
  
  if ( ! auth_result ) {
    cxapp::cxapp_log("Access denied", attr = log_attributes)
    res$status <- 403  # Forbidden
    return(list( "error" = "Access denied"))
  }
  
  
  # - log authentication
  
  cxapp::cxapp_log( paste( "Authorized", 
                           ifelse( ! is.null( attr(auth_result, "principal") ), attr(auth_result, "principal"), "unkown" ) ),
                    attr = log_attributes )
  
  
  # - add principal to log attributes
  if ( ! is.null( attr(auth_result, "principal") ) )
    log_attributes <- append( log_attributes, attr(auth_result, "principal") )
  
  
  
  # -- look for query categories

  qry_lst <- req$argsQuery
  names(qry_lst) <- base::tolower(names(qry_lst))
  

  qry_categories <- c( "event", "type", "class", "reference", "object", "actor", "env" )
  
  qry_filter <- list()

  for ( xcat in qry_categories )
    if ( xcat %in% names(qry_lst) ) {
      
      xcat_ref <- paste0( xcat, "s")
      
      if ( ! xcat_ref %in% names(qry_filter) )
        qry_filter[[ xcat_ref ]] <- character(0)

      # - append to manage ?opt=value&opt=value2      
      qry_filter[[ xcat_ref ]] <- append( qry_filter[[ xcat_ref ]],
                                          base::trimws(base::unlist(base::strsplit( qry_lst[[ xcat ]], ",", fixed = TRUE ), use.names = FALSE )) )
      
    }

  
  # -- date range

  for ( xopt in c( "from", "to" ) )
    if ( xopt %in% names(qry_lst) ) {
      
      if ( ! grepl( "^\\d{8}T\\d{6}$", qry_lst[[ xopt ]], ignore.case = TRUE, perl = TRUE) ) {
        res$status <- 400  # bad request
        res$body <- list( "error" = paste( "The", xopt, "date/time is in an invalid format" ) )
        return(res)
      }
  
      # - initialize with whatever value
      qry_filter[[xopt]] <- base::trimws( qry_lst[[xopt]] )
  
    }

  
  # -- number of records and pagination

  for ( xopt in c( "limit", "offset") )
    if ( xopt %in% names(qry_lst) )
      qry_filter[[ xopt ]] <- qry_lst[[ xopt ]]
    


  # -- get list of audited actions   
  
  dbpool <- base::get(".auditor.dbpool", envir = .GlobalEnv) 
  dbcon <- pool::poolCheckout( dbpool )
  
  qry_result <- try( auditor.service::auditor_list( qry_filter, connection = dbcon ), silent = TRUE )

  pool::poolReturn(dbcon)

  

  if ( inherits( qry_result, "try-error" ) ) {
    print(qry_result)
    
    res$status <- 500 # Internal error
    return( list( "error" = paste( "Failed to retrieve list of audit records" ) ) )
  }
  
  
  res$status <- 200  # OK
  
  res$setHeader( "content-type", "application/json" )
  res$body <- jsonlite::toJSON( qry_result, auto_unbox = TRUE, pretty = TRUE )
  
  cxapp::cxapp_log( "Audit record list", attr = log_attributes )
  

  return(res)  
}







#* List audit records
#* 
#* @post /api/records
#* 
#* @response 201 Created
#* @response 400 Bad Request
#* @response 401 Unauthorized
#* @response 403 Forbidden
#* @response 500 Internal Server Error
#* 

function( req, res ) {
  
  # -- default attributes
  log_attributes <- c( base::toupper(req$REQUEST_METHOD), 
                       req$REMOTE_ADDR, 
                       req$PATH_INFO )
  
  
  # -- Authorization
  
  if ( ! "HTTP_AUTHORIZATION" %in% names(req) ) {
    cxapp::cxapp_log("Authorization header missing", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return(list( "error" = "Authorization header missing"))
  }
  
  
  auth_result <- try( cxapp::cxapp_authapi( req$HTTP_AUTHORIZATION ), silent = FALSE )
  
  if ( inherits( auth_result, "try-error" ) ) {
    cxapp::cxapp_log("Authorization failed", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return(list( "error" = "Authorization failed"))
  }
  
  
  if ( ! auth_result ) {
    cxapp::cxapp_log("Access denied", attr = log_attributes)
    res$status <- 403  # Forbidden
    return(list( "error" = "Access denied"))
  }
  
  
  # - log authentication
  
  cxapp::cxapp_log( paste( "Authorized", 
                           ifelse( ! is.null( attr(auth_result, "principal") ), attr(auth_result, "principal"), "unkown" ) ),
                    attr = log_attributes )
  
  
  # - add principal to log attributes
  if ( ! is.null( attr(auth_result, "principal") ) )
    log_attributes <- append( log_attributes, attr(auth_result, "principal") )
 
  
  
  # -- process request

  audit_records <- list()
  
  if ( ! is.null(req$postBody) && ! any(is.na(req$postBody)) && (length(req$postBody) != 0) && ( base::trimws(base::as.character( utils::head(req$postBody, n = 1) )) != "" ) )
    audit_records <- try( jsonlite::fromJSON( req$postBody, simplifyDataFrame = FALSE, simplifyMatrix = FALSE ), silent = FALSE )
  
  if ( inherits( audit_records, "try-error" ) ) {
    cxapp::cxapp_log("Audit records not in a valid format", attr = log_attributes)
    res$status <- 400  # Bad request
    return(list( "error" = "Invalid record format provided"))
  }

  # note: auditor_save() currently expecting a list of lists
  if ( all( c( "event", "type", "reference") %in% names(audit_records) ) )
    audit_records <- list( audit_records )
  
  

  # -- post to database
  dbpool <- base::get(".auditor.dbpool", envir = .GlobalEnv) 
  dbcon <- pool::poolCheckout( dbpool )
  
  post_result <- try( auditor.service::auditor_save( audit_records, connection = dbcon ), silent = FALSE )
  
  pool::poolReturn(dbcon)

  if ( inherits( post_result, "try-error" ) || ! post_result ) {
    res$status <- 500 # Internal error
    return(list( "error" = "Failed to register audit records"))
  }

  
    
  cxapp::cxapp_log( paste( as.character(length(audit_records)), "audit record(s) registered" ), attr = log_attributes )

    
  res$status <- 201  # Created

  return(list( "message" = paste( as.character(length(audit_records)), "audit record(s) registered" ) ))  
}





#* Get an audit records
#* 
#* @get /api/records/<id>
#* 
#* @response 200 OK
#* @response 400 Bad Request
#* @response 401 Unauthorized
#* @response 403 Forbidden
#* @response 404 Not Found
#* @response 500 Internal Server Error
#* 

function( id, req, res ) {
  
  
  # -- default attributes
  log_attributes <- c( base::toupper(req$REQUEST_METHOD), 
                       req$REMOTE_ADDR, 
                       req$PATH_INFO )
  
  
  # -- Authorization
  
  if ( ! "HTTP_AUTHORIZATION" %in% names(req) ) {
    cxapp::cxapp_log("Authorization header missing", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization header missing")
  }
  
  
  auth_result <- try( cxapp::cxapp_authapi( req$HTTP_AUTHORIZATION ), silent = TRUE )
  
  if ( inherits( auth_result, "try-error" ) ) {
    cxapp::cxapp_log("Authorization failed", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization failed")
  }
  
  
  if ( ! auth_result ) {
    cxapp::cxapp_log("Access denied", attr = log_attributes)
    res$status <- 403  # Forbidden
    return("Access denied")
  }
  
  
  # - log authentication
  
  cxapp::cxapp_log( paste( "Authorized", 
                           ifelse( ! is.null( attr(auth_result, "principal") ), attr(auth_result, "principal"), "unkown" ) ),
                    attr = log_attributes )
  
  
  # - add principal to log attributes
  if ( ! is.null( attr(auth_result, "principal") ) )
    log_attributes <- append( log_attributes, attr(auth_result, "principal") )
  
  
  # -- process request
  
  if ( ! uuid::UUIDvalidate( id ) ) {
    res$status <- 400 # Bad request
    return( list( "error" = "Audit record identifier is an invalid format" ) )
  }
  
  
  
  
  # -- post to database
  dbpool <- base::get(".auditor.dbpool", envir = .GlobalEnv) 
  dbcon <- pool::poolCheckout( dbpool )
  
  qry_result <- try( auditor.service::auditor_record( id, connection = dbcon ), silent = TRUE )
  
  pool::poolReturn(dbcon)
  
  if ( inherits( qry_result, "try-error" ) ) {
    res$status <- 500 # Internal error
    return( list( "error" = paste( "Failed to register audit records" ) ) )
  }
  
  
  if ( length(qry_result) == 0 ) {
    res$status <- 404   # Not Found
    return( list( "error" = "Record not found" ) )
  }
  
  
  
  
  res$status <- 200  # OK
  
  res$setHeader( "content-type", "application/json" )
  res$body <- jsonlite::toJSON( qry_result, auto_unbox = TRUE, pretty = TRUE )
  
  cxapp::cxapp_log( "Audit record retrieved", attr = log_attributes )
  
  
  return(res)  
}


#* Ping service
#* 
#* @get /api/info
#* 
#* @response 200 OK
#* @response 401 Unauthorized
#* @response 403 Forbidden
#* @response 500 Internal Error
#* 

function( req, res ) {
 
  
  cfg <- cxapp::.cxappconfig()
  
  
  # -- default attributes
  log_attributes <- c( base::toupper(req$REQUEST_METHOD), 
                       req$REMOTE_ADDR, 
                       req$PATH_INFO )
  
  
  # -- Authorization
  
  if ( ! "HTTP_AUTHORIZATION" %in% names(req) ) {
    cxapp::cxapp_log("Authorization header missing", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization header missing")
  }
  
  
  auth_result <- try( cxapp::cxapp_authapi( req$HTTP_AUTHORIZATION ), silent = TRUE )
  
  if ( inherits( auth_result, "try-error" ) ) {
    cxapp::cxapp_log("Authorization failed", attr = log_attributes)
    res$status <- 401  # Unauthorized
    return("Authorization failed")
  }
  
  
  if ( ! auth_result ) {
    cxapp::cxapp_log("Access denied", attr = log_attributes)
    res$status <- 403  # Forbidden
    return("Access denied")
  }
  
  
  # - log authentication
  
  cxapp::cxapp_log( paste( "Authorized", 
                           ifelse( ! is.null( attr(auth_result, "principal") ), attr(auth_result, "principal"), "unkown" ) ),
                    attr = log_attributes )
  
  
  # - add principal to log attributes
  if ( ! is.null( attr(auth_result, "principal") ) )
    log_attributes <- append( log_attributes, attr(auth_result, "principal") )
  
  
  # -- assemble information
  lst <- list( "service" = "auditor", 
               "version" = as.character(utils::packageVersion("auditor.service")), 
               "database" = list() )
  
  
  # - add database pool details
  
  lst_pool <- list()
  
  dbpool <- base::get(".auditor.dbpool", envir = .GlobalEnv) 
  pool_details <- capture.output(dbpool)

  if ( any(grepl( "checked\\s+out:", pool_details, ignore.case = TRUE)) )
    lst_pool[["active.connections"]] <- gsub( ".*checked\\s+out:\\s+(\\d+)", "\\1", 
                                              pool_details[ grepl( "checked\\s+out:", pool_details, ignore.case = TRUE) ],
                                              ignore.case = TRUE ) 

  if ( any(grepl( "available\\s+in\\s+pool:", pool_details, ignore.case = TRUE)) )
    lst_pool[["available.connections"]] <- gsub( ".*available\\s+in\\s+pool:\\s+(\\d+)", "\\1",
                                                 pool_details[ grepl( "available\\s+in\\s+pool:", pool_details, ignore.case = TRUE) ],
                                                 ignore.case = TRUE ) 
  
  if ( any(grepl( "max\\s+size:", pool_details, ignore.case = TRUE)) )
    lst_pool[["max.connections"]] <- gsub( ".*max\\s+size:\\s+(\\d+)", "\\1",
                                           pool_details[ grepl( "max\\s+size:", pool_details, ignore.case = TRUE) ],
                                           ignore.case = TRUE ) 

  
  if ( length(lst_pool) > 0 )
    lst[["database"]][["pool"]] <- lst_pool

  
  # - add database configuration details
  
  lst_dbcfg <- list()
  
  for( xopt in c( "db.vendor", "db.driver", "db.host", "db.port", "db.username" ) )
    lst_dbcfg[[ xopt ]] <- cfg$option( xopt, unset = "<not set>" )
  
  lst_dbcfg[["db.password"]] <- ifelse( is.na( cfg$option( "db.password", unset = NA) ), "<not set>", "<set>" )
    

  for( xopt in c( "db.pool.minsize", "db.pool.maxsize", "db.pool.idletimeout" ) )
    lst_dbcfg[[ xopt ]] <- cfg$option( xopt, unset = "<default>" )
  

  lst[["database"]][["configuration"]] <- lst_dbcfg

  
  

  res$status <- 200  # OK
  
  res$setHeader( "content-type", "application/json" )
  res$body <- jsonlite::toJSON( lst, auto_unbox = TRUE, pretty = TRUE )
  
  cxapp::cxapp_log( "Audit service information", attr = log_attributes )
  
  
  return(res)  

}



#* Ping service
#* 
#* @get /api/ping
#* 
#* @response 200 OK
#* @response 500 Internal Error
#* 

function( req, res ) {
  
  # -- truly OK
  res$status <- 200
  
}



#' (Development) Identify node by unique R session ID
#' 
#' @return Vector of identifying attributes
#' 
#' @export

dev_appnode <- function() {

  
  if ( ! base::exists( ".appnode", envir = .GlobalEnv ) )
    base::assign( ".appnode", digest::digest( uuid::UUIDgenerate(), algo = "crc32", file = FALSE), envir = .GlobalEnv )

  return(invisible( base::get(".appnode", envir = .GlobalEnv) ))
}
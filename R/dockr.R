#' @title dockr class
#'
#' @description
#' A R6 Docker class as a wrapper for the docker commands.
#'
dockr <- R6::R6Class(
  classname = "dockr",
  cloneable = TRUE,

  public = list(

    #' Docker System Wrapper
    #'
    #' @description
    #' A Docker wrapper to run system commands for image management
    #'
    #' @param process The system process. Plan is to add `Podman` support but currently only
    #' setup for `docker`. Although Podman commands are formatted in a similar context.
    #'
    #' @param commands The main docker commands. Currently support commands
    #' are "image", "container", "search", "build", "history", "inspect".
    #'
    #' @param options the `command` option arguments or `image`
    #'
    #' @param args Additional arguments or flags for the docker commands
    #'
    #' @export
    initialize = function(process = NA, commands = NULL, options = NULL, args = NULL) {

      private$process = process
      private$commands = commands
      private$options = options
      private$args = args
      private$process_check(process)
      private$commands_check(commands)
      private$options_check(options, args)
      private$format_cmd()
      private$docker_command_run()
    },

    #' @description
    #' Prints the full command to the console for viewing.
    print = function() {
      cat(paste("|", cli::style_bold("Command:"),
        paste(private$process, private$commands, private$options, private$args)), "\n"
      )
      invisible(self)
    },

    #' @description
    #' Displays returned output in `tibble` format.
    show_output = function(){
      dplyr::as_tibble(private$output)
    },

    #' @description
    #' Show the json in pretty format from the command
    show_json = function(){
      jsonlite::toJSON(private$json_format, pretty = TRUE)
    }
  ),

  # Private List ------------------------------------------------------------

  private = list(

    process = NULL,
    commands = NULL,
    options = NULL,
    output = NULL,
    args = NULL,
    cmd_string = NULL,
    json_format = NULL,

    format_cmd = function(){
      cmd <- paste(private$process,
        private$commands,
        #private$options,
        ifelse(isTRUE(is.null(private$options)), "", private$options),
        ifelse(isTRUE(is.null(private$args)), "", private$args),
        "--format '{{json .}}'")
      private$cmd_string <- cmd
    },

    docker_command_run = function(){


      if(private$commands %in% c("info") & isTRUE(is.null(private$options)) & isTRUE(is.null(private$args))) {
        private$run_formatted()
      } else if(private$options %in% c("start", "stop", "pause", "unpause", "restart", "kill") & isFALSE(is.null(private$args))){
        private$run_nonformat()
      } else if(private$commands %in% c("image", "container", "search", "history", "inspect", "info")){
        private$run_formatted()
      }

    },

    run_nonformat = function(){
      cmd <- paste(private$process, private$commands, private$options, ifelse(isTRUE(is.null(private$args)), "", private$args))
      private$cmd_string <- cmd
      system(private$cmd_string)
    },

    #' Formatting Function
    #'
    #' @importFrom tidyr unnest_longer unnest_wider
    #' @importFrom jsonlite fromJSON
    run_formatted = function(){

      json_format <- system(private$cmd_string, intern = TRUE)

      if(length(json_format) == 0) {cli::cli_abort("Nothing to return")}

      # Check the length of json string
      if(length(json_format) > 1) {
        data <- vector("list", length(json_format))

        for(i in seq_along(json_format)){
          data[[i]] <- jsonlite::fromJSON(json_format[[i]])
        }

        private$json_format <- data
        # return results for string length > 1
        df <- dplyr::tibble(data = list(data))
        df <- df |>
          tidyr::unnest_longer(data) |>
          tidyr::unnest_wider(data)
      } else {
        df <- jsonlite::fromJSON(json_format)
        private$json_format <- df
        df <- dplyr::tibble(data = list(df))

        df <- df |>
          tidyr::unnest_wider(data)
      }
      private$output <- df

    },

    # System process
    process_check = function(process){
      private$process <- match.arg(process, c("docker", "podman"))
      return(private$process)
    },

    # Supported docker commands
    commands_check = function(commands){
      private$commands <- match.arg(commands, c("image", "container", "search", "history", "inspect", "info"))
    },

    # Check arguments
    options_check = function(options, args){

      if(private$commands %in% "image"){
        private$options <- match.arg(options, c("list", "ls"))
        private$args <- ifelse(isTRUE(is.null(private$args)),
          "",
          match.arg(args, c("--all", "--digests", "-a", "--quiet", "-q")))

      }

      if(private$commands %in% "container"){

        private$options <- match.arg(options, c("attach", "start", "inspect", "stop",
          "ls", "kill", "list", "pause", "unpause", "restart"))

        private$args <- args

      }

      if(private$commands %in% "search"){
        private$options <- options
      }

      if(private$commands %in% "inspect"){
        private$options <- options
      }

      if(private$commands %in% "history"){
        private$options <- options
      }

      if(private$commands %in% "info"){
        private$options <- options
        private$args <- args
      }

      return(private$options)
    }
  )
)


# Docker functions  -----------------------------------------------------

#' Docker Images
#'
#' Display a table of images in the docker register
#'
#' @importFrom rlang .data
#' @export
docker_images <- function(){

  dock_images <- dockr$new(process = "docker",
    commands = "image",
    options = "ls")$show_output()

  dock_images |>
    dplyr::select(.data$Repository, .data$ID, .data$Tag, .data$Size)

}

#' Docker Containers
#'
#' A table of running containers
#'
#' @export
docker_containers <- function(){

  dockr$new(process = "docker",
    commands = "container",
    options = "ls")$show_output()

}

#' Docker Search
#'
#' @param search A character string of image to search on DockerHub. Returns it in `tibble`
#' format.
#'
#' @export
docker_search <- function(search = "rstudio"){
  dockr$new(process = "docker",
    commands = "search",
    options = search)$show_output()
}



#' Check Docker Services
#'
#' Performs a quick system check for installation
#' of Docker and if not found, gives URL to page for install instructions.
#'
#'
#' @export
docker_check <- function(){

  if(Sys.which("docker") == "") {

    cli::cli_alert_warning("Docker was not found on your system")

    if(Sys.info()[["sysname"]] == "Darwin"){
      cli::cli_alert_info("Visit: {.url https://docs.docker.com/desktop/install/mac-install/}")
    }

    if(Sys.info()[["sysname"]] == "Windows"){
      cli::cli_alert_info("Visit: {.url https://docs.docker.com/desktop/install/windows-install/}")
    }

    if(Sys.info()[["sysname"]] == "Linux"){
      cli::cli_alert_info("Visit: {.url https://docs.docker.com/engine/install/}")
    }

  } else {
    sys_cmd <- processx::run(command = "docker",
      args = c("-v"),
      error_on_status = FALSE)

    cli::cli_alert_success('{gsub("[\r\n]", "", sys_cmd$stdout)}')

  }

}




#' Docker Login
#'
#' Log into docker hub using a `DOCKER_PAT` that should be setup
#' through \url{https://hub.docker.com} and assigned to `.Renviron`.
#'
#' @param username Character string of dockerhub user login
#'
#' @export
docker_login <- function(username){

  cli::cli_h1("Docker Login")
  #TODO this needs to be update for secure login
  # also to return state to check if already logged in processx::new
  url_helper = "https://hub.docker.com/settings/general"

  # Set username
  if(is.null(username)){
    cli::cli_abort("No {.emph username} provided")
  } else {
    USER = username
  }

  # set docker hub token
  if(Sys.getenv("DOCKER_PAT") == "") {
    cli::cli_abort("No DOCKER_PAT token can be found in {.emph .Renviron}
                         Visit: {.url {url_helper}}")
  } else {
    PWD <- Sys.getenv("DOCKER_PAT")
  }

  exec_cmd <- paste0("echo ",
    PWD,
    " | docker login -u ",
    USER,
    " --password-stdin")
  #
  # p <- processx::process$new(
  #   "docker",
  #   c("login", "-u", "gaborcsardi", "--password-stdin"),
  #   stdin = "|", stdout = "|", stderr = "|")

  system(exec_cmd, intern = TRUE)

}

#' Docker Logout
#'
#' Log out of docker
#'
#' @export
docker_logout <- function(){

  cli::cli_h1("Docker Logout")

  sys_cmd <- sys::exec_internal("docker", "logout")

}


#' Docker Push Image
#'
#' Push container image to \url{https://hub.docker.com/}. Naming Convention in Docker Hub:
#' Very popularly known software are given their own name as Docker image. For individuals and
#' corporates, docker gives a username. And all the images can be pushed to a particular username.
#' And can be pulled using the image name with a username.
#'
#'
#' @param name The user/name of the docker image
#' @param tag Version or tag of image. Defaults to latest.
#'
#' @export
docker_push <- function(name = NULL, tag = NULL){

  cli::cli_h1("Docker Push {.val {name}}:{.val {tag}}")
  #docker_login()

  if(is.null(tag)){
    tag <- "latest"
  } else {
    tag <- tag
  }

  #sys_cmd <- paste0("docker push ", name, ":", tag)

  cli::cli_alert_info("{.emph Have you ever heard the tragedy of Darth Plagueis, the wise?}",
    class = cli::cli_div(theme = list(span.emph = list(color = "orange"))))

  #system(sys_cmd)
  #cli::cli_alert_success("Done")

}


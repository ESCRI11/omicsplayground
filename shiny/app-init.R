##
## This file is part of the Omics Playground project.
## Copyright (c) 2018-2022 BigOmics Analytics Sagl. All rights reserved.
##

message("===============================================================")
message("======================= init.R ================================")
message("===============================================================")

## Parse access logs
ACCESS.LOG <- NULL
if(0) {
    access.dirs = c("/var/www/html/logs", "/var/log/apache2","/var/log/apache",
                    "../logs","/var/log/httpd","/var/log/nginx")
    access.dirs <- access.dirs[dir.exists(access.dirs)]
    access.dirs
    ##ACCESS.LOG <- pgx.parseAccessLogs(access.dirs[], filter.get=NULL)
    ACCESS.LOG <- pgx.parseAccessLogs(access.dirs[], filter.get="playground")
    names(ACCESS.LOG)
    sum(ACCESS.LOG$visitors$count)
}

##-----------------------------------------------------
## Initialize ORCA server (DEPRECATED)
##-----------------------------------------------------
## see: pgx-module.R
ORCA <- NULL
if(FALSE && getOption("OMICS_ORCA_RUN", TRUE)){
    ORCA <- initOrca(launch=TRUE) 
    class(ORCA)
    if(is.null(ORCA)) {
        stop("##### FATAL:: Could not connect to ORCA server. Please start ORCA. #####")
    }
}

##======================================================================
##==================== FUNCTIONS =======================================
##======================================================================

sever_screen0 <- shiny::tagList(
    shiny::tags$h1(
      "Houston, we have a problem", style="color:white;font-family:lato;"
    ),
    shiny::p("You have been disconnected!", style="font-size:15px;"),
    shiny::br(),
    shiny::div(shiny::img(src=base64enc::dataURI(file="www/lost-in-space.gif"),
                          width=500,height=250)),
    shiny::br(),
    sever::reload_button("Relaunch", class = "info")
)

sever_screen <- shiny::tagList(
    shiny::tags$h1(
        "Houston, we have a problem", style = "color:white;font-family:lato;"
    ),
    shiny::p("You have been disconnected!", style="font-size:15px;"),
    shiny::br(),
    shiny::div(shiny::img(src=base64enc::dataURI(file="www/lost-in-space.gif"),
                          width=500,height=250)),
    shiny::div(
        id="logSub",
##        shiny::textAreaInput(
##               inputId = "logMsg",
##               label = "",
##               width = "100%", height="80px",
##               value = "If this was a crash, please help and describe here the last thing you did."
##        ),
        shiny::br(),
        shiny::tags$a(
            onClick = "sendLog()", 
            class = "btn btn-sm btn-warning", 
            "Send error to developers"
        )
    ),
    shiny::div(
        id="logSubbed",
        style="display:none;",
        shiny::p("Mission Control has been notified. Thank you!", style="font-size:15px;")
    ),
    shiny::br(),
    shiny::div(
        id="sever-reload-btn",
        sever::reload_button("Relaunch", class = "info"),
        style="display:none;"             
    )
)

sever_screen2 <- function(session_id) {
  shiny::tagList(
    shiny::tags$h1(
      "Houston, we have a problem", style = "color:white;font-family:lato;"
    ),
    shiny::p("You have been disconnected!", style="font-size:15px;"),
    shiny::br(),
    shiny::div(shiny::img(src=base64enc::dataURI(file="www/lost-in-space.gif"),
                          width=500,height=250)),
    shiny::div(
      id="logSub",
      ##        shiny::textAreaInput(
      ##               inputId = "logMsg",
      ##               label = "",
      ##               width = "100%", height="80px",
      ##               value = "If this was a crash, please help and describe here the last thing you did."
      ##        ),
      shiny::br(),
      shiny::tags$a(
        onClick = HTML(paste0("sendLog2('",session_id,"')")),
        class = "btn btn-sm btn-warning", 
        "Send error to developers"
      )
    ),
    shiny::div(
      id="logSubbed",
      style="display:none;",
      shiny::p("Mission Control has been notified. Thank you!", style="font-size:15px;")
    ),
    shiny::br(),
    shiny::div(
      id="sever-reload-btn",
      sever::reload_button("Relaunch", class = "info"),
      style="display:none;"             
    )
  )
}

tipify2 <- function(...) {
    shinyBS::tipify(..., placement="top", options = list(container = "body"))
}
tipifyL <- function(...) {
    shinyBS::tipify(..., placement="left", options = list(container = "body"))
}
tipifyR <- function(...) {
    shinyBS::tipify(..., placement="right", options = list(container = "body"))
}
tipifyT <- function(...) {
    shinyBS::tipify(..., placement="top", options = list(container = "body"))
}
tipifyB <- function(...) {
    shinyBS::tipify(..., placement="bottom", options = list(container = "body"))
}

## premium.feature <- function(...) {
##     message("[premium.feature] USER_MODE = ",USER_MODE)
##     message("[premium.feature] DEV = ",DEV)        
##     el <- list(...)
##     if(USER_MODE %in% c("pro","premium","dev")) return(el)
##     shinyBS::tipify(shinyjs::disabled(...),
##            "This is a Premium feature. Upgrade to enable this feature."
##            )    
## }

in.shinyproxy <- function() {
    ## Determine if we are in ShinyProxy
    ##
    vars <- c("SHINYPROXY_USERNAME","SHINYPROXY_USERGROUPS",
              "PLAYGROUND_USERID","PLAYGROUND_LEVEL")
    vars <- c("SHINYPROXY_USERNAME")
    vals <- sapply(vars,Sys.getenv)
    all(vals!="") && dir.exists("/omicsplayground")
}

tabRequire <- function(pgx, slot, tabname, subtab) {
    if(!slot %in% names(pgx)) {
        cat(paste("[MAIN] object has no ",slot," results. hiding tab.\n"))
        shiny::hideTab(tabname, subtab)
    } else {
        shiny::showTab(tabname, subtab)
    }
}

fileRequire <- function(file, tabname, subtab) {
    file1 <- search_path(c(FILES,FILESX),file)
    has.file <- !is.null(file1) && file.exists(file1)
    if(!has.file) {
        message(paste("[MAIN] file ",file," not found. Hiding",subtab,"\n"))
        shiny::hideTab(tabname, subtab)
    } else {
        message(paste("[MAIN] file ",file," available. Showing",subtab,"\n"))        
        shiny::showTab(tabname, subtab)
    }
}

tabView <- function(title, tab.inputs, tab.ui, id=title) {
    shiny::tabPanel(title, id=id,
             shiny::sidebarLayout(
                 shiny::sidebarPanel( width=2, tab.inputs, id="sidebar"),
                 shiny::mainPanel( width=10, tab.ui)
             ))
}

toggleTab <- function(inputId, target, do.show, req.file=NULL ) {
    if(!is.null(req.file)) {
        file1 <- search_path(c(FILES,FILESX),req.file)
        has.file <- !is.null(file1[1])
        do.show <- do.show && has.file
    }
    if(do.show) {
        shiny::showTab(inputId, target)
    }
    if(!do.show) {
        shiny::hideTab(inputId, target)
    }
}


## dev.tabView <- function(title, tab.inputs, tab.ui) {
##     if(!DEV.MODE) return(NULL)
##     tabView(title, tab.inputs, tab.ui)
## }
## dev.tabPanel <- function(id, ui) {
##     if(!DEV.MODE) return(NULL)
##     shiny::tabPanel(id, ui)
## }

social_buttons <- function() {
    shiny::div(
        id="social-buttons",
        shiny::tagList(
            shinyBS::tipify( tags$a( href="https://omicsplayground.readthedocs.io", shiny::icon("book"), target="_blank"),
                   "Read our online documentation at Read-the-docs", placement="top"),
            shinyBS::tipify( tags$a( href="https://www.youtube.com/watch?v=_Q2LJmb2ihU&list=PLxQDY_RmvM2JYPjdJnyLUpOStnXkWTSQ-",
                           shiny::icon("youtube"), target="_blank"),
                   "Watch our tutorials on YouTube", placement="top"),
            shinyBS::tipify( tags$a( href="https://github.com/bigomics/omicsplayground",
                           shiny::icon("github"), target="_blank"),
                   "Get the source code or report a bug at GitHub", placement="top"),
            shinyBS::tipify( tags$a( href="https://hub.docker.com/r/bigomics/omicsplayground",
                           shiny::icon("docker"), target="_blank"),
                   "Pull our docker from Docker", placement="top"),
            shinyBS::tipify( tags$a( href="https://groups.google.com/d/forum/omicsplayground",
                           shiny::icon("users"), target="_blank"),
                   "Get help at our user forum", placement="top")            
        )
    )
}

TAGS.JSSCRIPT =
    ## https://stackoverflow.com/questions/36995142/get-the-size-of-the-window-in-shiny
    tags$head(tags$script('
    var dimension = [0, 0];
    $(document).on("shiny:connected", function(e) {
        dimension[0] = window.innerWidth;
        dimension[1] = window.innerHeight;
        Shiny.onInputChange("dimension", dimension);
    });
    $(window).resize(function(e) {
        dimension[0] = window.innerWidth;
        dimension[1] = window.innerHeight;
        Shiny.onInputChange("dimension", dimension);
    });
')) 


## From https://github.com/plotly/plotly.js/blob/master/src/components/modebar/buttons.js
all.plotly.buttons = c(
    "toImage",
    "senDataToCloud","editInChartStudio","zoom2d","pan2d","select2d",
    "lasso2d","drawclosedpath","drawopenpath","drawline","drawrect",
    "drawcircle","eraseshape","zoomIn2d","zoomOut2d",
    "autoScale2d","resetScale2d","zoom3d","pan3d",
    "orbitRotation","tableRotation","resetCameraDefault3d",
    "resetCameraLastSave3d","hoverClosest3d","zoomInGeo",
    "zoomOutGeo","resetGeo","hoverClosestGeo","hoverClosestGl2d",
    "hoverClosestPie","resetViewSankey","toggleHover",
    "hoverClosestCartesian","hoverCompareCartesian",
    "resetViews","toggleSpikelines",
    "resetViewMapbox","zoomInMapbox","zoomOutMapbox")




##======================================================================
##==================== END-OF-FILE =====================================
##======================================================================

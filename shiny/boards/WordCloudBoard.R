##
## This file is part of the Omics Playground project.
## Copyright (c) 2018-2020 BigOmics Analytics Sagl. All rights reserved.
##

message(">>> sourcing WordCloudBoard")

WordCloudInputs <- function(id) {
    ns <- shiny::NS(id)  ## namespace
    shiny::tagList(
        shiny::uiOutput(ns("description")),
        shiny::uiOutput(ns("inputsUI"))
    )
}

WordCloudUI <- function(id) {
    ns <- shiny::NS(id)  ## namespace
    shiny::fillCol(
        flex = c(1),
        height = 780,
        shiny::tabsetPanel(
            id = ns("tabs"),
            shiny::tabPanel("WordCloud",uiOutput(ns("wordcloud_UI")))
            ## shiny::tabPanel("Fire plot (dev)",uiOutput(ns("fireplot_UI")))            
        )
    )
}

WordCloudBoard <- function(input, output, session, env)
{
    ns <- session$ns ## NAMESPACE

    inputData <- env[["load"]][["inputData"]]
    selected_gxmethods <- env[["expr"]][["selected_gxmethods"]]
    selected_gsetmethods <- env[["enrich"]][["selected_gsetmethods"]]

    fullH = 750
    rowH = 660  ## row height of panel
    tabH = 200  ## row height of panel
    tabH = '70vh'  ## row height of panel    

    
    description = "<b>WordCloud analysis</b>. <br> WordCloud analysis or 'keyword enrichment' analysis computes the enrichment of keywords for the contrasts. The set of words frequently appearing in the top ranked gene sets form an unbiased description of the contrast."
    output$description <- shiny::renderUI(shiny::HTML(description))

    wc_infotext = paste("This module performs WordCloud analysis or 'keyword enrichment', i.e. it computes the enrichment of keywords for the contrasts. Frequently appearing words in the top ranked gene sets form an unbiased description of the contrast.
<br><br><br><br>
<center><iframe width='500' height='333' src='https://www.youtube.com/embed/watch?v=qCNcWRKj03w&list=PLxQDY_RmvM2JYPjdJnyLUpOStnXkWTSQ-&index=6' frameborder='0' allow='accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture' allowfullscreen></iframe></center>
")

    
    ##================================================================================
    ##========================= INPUTS UI ============================================
    ##================================================================================

    output$inputsUI <- shiny::renderUI({
        ui <- shiny::tagList(
            shinyBS::tipify( shiny::actionLink(ns("wc_info"), "Youtube", icon = shiny::icon("youtube") ),
                   "Show more information about this module."),
            shiny::hr(), shiny::br(),             
            shinyBS::tipify( shiny::selectInput(ns("wc_contrast"),"Contrast:", choices=NULL),
                   "Select the contrast corresponding to the comparison of interest.",
                   placement="top"),
            shinyBS::tipify( shiny::actionLink(ns("wc_options"), "Options", icon=icon("cog", lib = "glyphicon")),
                   "Show/hide advanced options", placement="top"),
            shiny::br(),
            shiny::conditionalPanel(
                "input.wc_options % 2 == 1", ns=ns,
                shiny::tagList(
                    shinyBS::tipify(shiny::checkboxInput(ns('wc_normalize'),'normalize activation matrix',TRUE),
                           "Click to 'normalize' the coloring of an activation matrices.")
                    ##tipify(shiny::checkboxInput(ns('wc_filtertable'),'filter signficant (tables)',FALSE),
                    ##"Click to filter the significant entries in the tables.")
                )
            )
        )
        ui
    })
    shiny::outputOptions(output, "inputsUI", suspendWhenHidden=FALSE) ## important!!!

    ##================================================================================
    ##======================= OBSERVE FUNCTIONS ======================================
    ##================================================================================
    
    shiny::observeEvent( input$wc_info, {
        shiny::showModal(shiny::modalDialog(
            title = shiny::HTML("<strong>WordCloud Analysis Board</strong>"),
            shiny::HTML(wc_infotext),
            easyClose = TRUE, size="l" ))
    })
    
    shiny::observe({
        ngs <- inputData()
        shiny::req(ngs)
        ct <- colnames(ngs$model.parameters$contr.matrix)
        ##ct <- c(ct,"<sd>")
        ct <- sort(ct)
        shiny::updateSelectInput(session, "wc_contrast", choices=ct )
    })
    
    ##---------------------------------------------------------------
    ##------------- Functions for WordCloud -------------------------
    ##---------------------------------------------------------------

    enrich_getWordFreqResults <- shiny::reactive({
        ngs <- inputData()
        shiny::req(ngs)
        if("wordcloud" %in% names(ngs)) {
            res <- ngs$wordcloud
        } else {
            dbg("**** CALCULATING WORDCLOUD ****\n")
            progress <- shiny::Progress$new()
            res <- pgx.calculateWordFreq(ngs, progress=progress, pg.unit=1)
            on.exit(progress$close())    
        }
        return(res)
    })

    enrich_getCurrentWordEnrichment <- shiny::reactive({

        res <- enrich_getWordFreqResults()
        shiny::req(res, input$wc_contrast)

        contr=1
        contr <- input$wc_contrast
        gsea1 <- res$gsea[[ contr ]]
        topFreq <- data.frame( gsea1, tsne=res$tsne, umap=res$umap)
        topFreq <- topFreq[order(-topFreq$NES),]
        
        ## update selectors
        words <- sort(res$gsea[[1]]$word)
        shiny::updateSelectInput(session, "enrich_wordcloud_exclude", choices=words)
        
        return(topFreq)
    })

    enrich_wordtsne.RENDER <- shiny::reactive({

        topFreq <- enrich_getCurrentWordEnrichment()

        df <- topFreq
        klr = ifelse( df$padj<=0.05, "red", "grey")    
        ps1 = 0.5 + 3*(1-df$padj)*(df$NES/max(df$NES))**3

        ## label top 20 words
        df$label <- rep(NA, nrow(df))
        jj <- head(order(-abs(df$NES)),20)
        df$label[jj] <- as.character(df$word[jj])
        cex=1
        ##cex=2.5
        

        if(input$enrich_wordtsne_algo=="tsne") {
            p <- ggplot2::ggplot(df, ggplot2::aes(tsne.x, tsne.y, label=label))
        } else {
            p <- ggplot2::ggplot(df, ggplot2::aes(umap.x, umap.y, label=label))
        }
        p <- p +
            ggplot2::geom_point( size=cex*ps1, color=klr) +
            ggrepel::geom_text_repel(size=4*cex) +
            ##geom_text_repel(point.padding=NA, size=cex) +
            ##scale_x_continuous( expand=c(0,0) ) +
            ##scale_y_continuous( expand=c(0,0) ) +
            ##coord_cartesian( xlim=c(0,1), ylim=c(0,1)) +
            ggplot2::theme_bw() +
            ggplot2::theme( axis.text.x=element_blank(),
                  axis.text.y=element_blank(),
                  axis.ticks=element_blank()) 

        return(p)
    })

    enrich_wordtsne.PLOTLY <- shiny::reactive({

        topFreq <- enrich_getCurrentWordEnrichment()
        
        df <- topFreq
        klr = ifelse( df$padj<=0.05, "red", "grey")    
        ps1 = 0.5 + 3*(1-df$padj)*(df$NES/max(df$NES))**3

        ## label top 20 words
        df$label <- rep("", nrow(df))
        jj <- head(order(-abs(df$NES)),20)
        df$label[jj] <- as.character(df$word[jj])
        cex=1
        ##cex=2.5
        df$abs.NES <- abs(df$NES)**2
        

        if(input$enrich_wordtsne_algo=="tsne") {
            pos = cbind( x=df$tsne.x, y=df$tsne.y)
        } else {
            pos = cbind( x=df$umap.x, y=df$umap.y)
        }
        
        plt <- plotly::plot_ly(
            df,
            text = df$word, hoverinfo = 'text'
            ## hovertemplate = paste0("%{text}<br>NES: %{NES}<extra> </extra>")
        ) %>%
            plotly::add_markers(
                type="scatter",
                x = pos[,1], y = pos[,2], 
                color = klr,
                size = ~abs.NES,
                ## sizes = c(5,100),
                marker = list(
                    ##size = 16,
                    ##sizes=c(20,400),
                    line = list(color="grey20", width=0.6)
                )) %>%
            plotly::add_annotations(
                x = pos[,1], y = pos[,2],
                text = df$label,
                font = list(size=12),
                ##xref = "x", yref = "y",
                showarrow = FALSE)

        ax <- list(
            title = "",
            showticklabels = FALSE,
            showgrid = FALSE
        )

        m <- list(
            l = 0,
            r = 0,
            b = 0,
            t = 0,
            pad = 4
        )

        plt <- plt %>%
            plotly::layout(
                xaxis = ax,
                yaxis = ax,
                showlegend = FALSE,
                margin = m
            )
        
        return(plt)
    })

    enrich_wordcloud.RENDER <- shiny::reactive({

        topFreq <- enrich_getCurrentWordEnrichment()
        df <- topFreq
        
        excl.words <- ""
        excl.words <- input$enrich_wordcloud_exclude
        ##cat("<enrich_wordcloud> 0: excl.words=",excl.words,"\n")
        ##cat("<enrich_wordcloud> 0: len.excl.words=",length(excl.words),"\n")
        if(length(excl.words)>0) {
            df <- df[ which(!df$word %in% excl.words), ]
        }
        
        cex1 <- 1+round((5*rank(abs(df$NES))/nrow(df))**2)    
        cex2 <- (-log10(df$padj))**1.0
        size <- 10*abs(cex1 * cex2)**1
        minsize <- tail(sort(size),250)[1]

        color.pal = input$enrich_wordcloud_colors
        



        ##wordcloud2( data.frame(word=df$word, size=size), size=1)
        ##d3Cloud(text = df$word, size = size)
        
        par(mar=c(1,1,1,1)*0)
        suppressWarnings( suppressMessages(
            wordcloud::wordcloud(
                           words = df$word, freq = size,
                           ##colors=brewer.pal(8, "Dark2"),
                           colors = RColorBrewer::brewer.pal(8, color.pal),
                           scale=c(2,0.1)*0.9, min.freq=minsize)
        ))
        
    })

    enrich_gseaplots.RENDER %<a-% shiny::reactive({
        
        dbg("enrich_gseaplots.RENDER: reacted")
        ngs <- inputData()
        alertDataLoaded(session,ngs)
        
        res <- enrich_getWordFreqResults()        
        topFreq <- enrich_getCurrentWordEnrichment()

        shiny::req(ngs, res, topFreq)
        ##req(input$wordcloud_enrichmentTable_rows_selected)

        dbg("enrich_gseaplots.RENDER: 1")
        
        ## get gset meta foldchange-matrix
        ##S <- sapply(ngs$gset.meta$meta, function(x) x$meta.fx)
        ##S <- S + 0.0001*matrix(rnorm(length(S)),nrow(S),ncol(S))
        ##rownames(S) <- rownames(ngs$gset.meta$meta[[1]])
        S <- res$S  ## geneset expressions
        
        keyword = "ribosomal"
        keyword = "lipid"
        keyword = "apoptosis"
        keyword = "cell.cycle"
        
        ##keyword <- input$enrich_wordcloud_clicked_word ## wordcloud2
        ##keyword <- input$d3word ## rWordcloud
        sel.row <- wordcloud_enrichmentTable$rows_selected()
        shiny::req(sel.row)
        keyword <- topFreq$word[sel.row]
        
        if( length(keyword)==0 || keyword[1] %in% c(NA,"") ) keyword <- "cell.cycle"
        cat("<enrich_gseaplots> 3: selected keyword=",keyword,"\n")

        dbg("enrich_gseaplots.RENDER: 2")
        
        ##targets <- grep(keyword, rownames(S), ignore.case=TRUE, value=TRUE)
        targets <- names(which(res$W[,keyword]==1))
        ##length(targets)
        
        if(0) {
            gmt <- list("set1"=targets)
            names(gmt)[1] = keyword

            i=1
            wres <- c()
            for(i in 1:ncol(S)) {
                res1 <- fgsea::fgsea( gmt, S[,i], nperm=400 )[,1:5]
                wres <- rbind(wres, as.data.frame(res1)[1,])
            }
            rownames(wres) <- colnames(S)
            wres$padj <- p.adjust( wres$pval, method="fdr")
            ##wres <- wres[order(-wres$NES),]
            
            nes <- wres$NES
            pv  <- wres$pval
            qv  <- wres$padj
            names(nes) <- names(pv) <- names(qv) <- rownames(wres)
        }

        dbg("enrich_gseaplots.RENDER: 3")
        
        keyword
        nes <- unlist(sapply(res[["gsea"]], function(G) G[match(keyword,G$word),"NES"]))
        pv  <- unlist(sapply(res[["gsea"]], function(G) G[match(keyword,G$word),"pval"]))
        qv  <- unlist(sapply(res[["gsea"]], function(G) G[match(keyword,G$word),"padj"]))
        names(qv) <- names(pv) <- names(nes) <- sub("[.]NES","",names(nes))

        dbg("enrich_gseaplots.RENDER: 4")
        
        top <- names(pv)[order(-abs(nes),pv)]
        ##top <- names(pv)[order(pv,-abs(nes))]
        top <- intersect(top, colnames(S))

        dbg("enrich_gseaplots.RENDER: 5")
        
        par(mfrow=c(3,3), mar=c(0.2,3.2,3.2,0.2), mgp=c(1.8,0.7,0))
        i=1
        for(i in 1:9) {
            if(i > length(top)) {
                frame()
            } else {
                a <- top[i]
                gsea.enplot(S[,a], targets, names=NULL, ##main=gs,
                            main = paste0("#",toupper(keyword),"\n@",a),
                            cex.main=0.9, len.main=80, xlab="")
                qv1 = formatC(qv[a],format="e", digits=3)
                nes1 = formatC(nes[a],format="f", digits=3)
                tt <- c(paste("NES=",nes1),paste("q=",qv1))
                legend("topright", tt, bty="n",cex=0.85)
            }
        }
        dbg("enrich_gseaplots.RENDER: done")
        
    })

    wordcloud_enrichmentTable.RENDER <- shiny::reactive({    

        df <- enrich_getCurrentWordEnrichment()
        shiny::req(df)
        df <- df[,c("word","pval","padj","ES","NES","size")]
        cat("<wordcloud_enrichmentTable.RENDER> dim(df)=",dim(df),"\n")

        ##do.filter <- input$wc_filtertable
        ##if(do.filter) df <- df[which(df$padj < 0.99),]
        
        numeric.cols <- colnames(df)[which(sapply(df, is.numeric))]
        numeric.cols
        tbl <- DT::datatable(
                       df, rownames=FALSE,
                       class = 'compact cell-border stripe hover',                  
                       extensions = c('Scroller'),
                       selection = list(mode='single', target='row', selected=1),
                       fillContainer = TRUE,
                       options=list(
                           dom = 'lfrtip', 
                           scrollX = TRUE, scrollY = tabH,
                           scroller=TRUE, deferRender=TRUE
                       )  ## end of options.list 
                   ) %>%
            DT::formatSignif(numeric.cols,4) %>%
            DT::formatStyle(0, target='row', fontSize='11px', lineHeight='70%') %>% 
            DT::formatStyle( "NES",
                            background = color_from_middle( df[,"NES"], 'lightblue', '#f5aeae'),
                            backgroundSize = '98% 88%', backgroundRepeat = 'no-repeat',
                            backgroundPosition = 'center') 
        ##tbl <- DT::datatable(df)
        return(tbl)
    })

    wordcloud_leadingEdgeTable.RENDER <- shiny::reactive({    

        ngs <- inputData()
        shiny::req(ngs, input$wc_contrast)

        df <- enrich_getCurrentWordEnrichment()

        sel.row=1
        sel.row <- wordcloud_enrichmentTable$rows_selected()
        shiny::req(df, sel.row)
        if(is.null(sel.row)) return(NULL)
        
        ee <- unlist(df$leadingEdge[sel.row])
        ee <- strsplit(ee, split="//")[[1]]

        ##fx <- ngs$gset.meta$meta[[1]][ee,"meta.fx"]
        ##fx <- ngs$gset.meta$meta[[1]][ee,"fc"][,"fgsea"]  ## real NES
        fx <- ngs$gset.meta$meta[[input$wc_contrast]][ee,"meta.fx"]
        names(fx) <- ee
        df <- data.frame("leading.edge"=ee, fx=fx )
        df <- df[order(-abs(df$fx)),]
        rownames(df) <- ee
        
        numeric.cols <- colnames(df)[which(sapply(df, is.numeric))]
        numeric.cols

        df$leading.edge <- wrapHyperLink(df$leading.edge, df$leading.edge)  ## add link
        
        tbl <- DT::datatable( df, rownames=FALSE, escape = c(-1,-2),
                             class = 'compact cell-border stripe hover',                  
                             extensions = c('Scroller'),
                             selection = list(mode='single', target='row', selected=1),
                             fillContainer = TRUE,
                             options=list(
                                 dom = 'lfrtip', 
                                 scrollX = TRUE, scrollY = tabH,
                                 scroller=TRUE, deferRender=TRUE
                             )  ## end of options.list 
                             ) %>%
            DT::formatSignif(numeric.cols,4) %>%
            DT::formatStyle(0, target='row', fontSize='11px', lineHeight='70%') %>% 
            DT::formatStyle( "fx",
                            background = color_from_middle( df[,"fx"], 'lightblue', '#f5aeae'),
                            backgroundSize = '98% 88%', backgroundRepeat = 'no-repeat',
                            backgroundPosition = 'center') 
        ##tbl <- DT::datatable(df)
        return(tbl)
    })


    plotWcActmap <- function(score, normalize, nterm, nfc) {
        
        ## reduce score matrix
        score = score[head(order(-rowMeans(score[,]**2)),nterm),,drop=FALSE] ## max terms    
        score = score[,head(order(-colSums(score**2)),nfc),drop=FALSE] ## max comparisons/FC

        cat("<wordcloud_actmap> dim(score)=",dim(score),"\n")
        score <- score + 1e-3*matrix(rnorm(length(score)),nrow(score),ncol(score))
        d1 <- as.dist(1-cor(t(score),use="pairwise"))
        d2 <- as.dist(1-cor(score,use="pairwise"))
        d1[is.na(d1)] <- 1
        d2[is.na(d2)] <- 1
        jj=1;ii=1:nrow(score)
        ii <- hclust(d1)$order
        jj <- hclust(d2)$order
        score <- score[ii,jj,drop=FALSE]
        
        colnames(score) = substring(colnames(score),1,30)
        rownames(score) = substring(rownames(score),1,50)
        colnames(score) <- paste0(colnames(score)," ")
        cex2=0.85

        par(mfrow=c(1,1), mar=c(1,1,1,1), oma=c(0,2,0,1))

        score2 <- score
        if(normalize) score2 <- t(t(score2) / apply(abs(score2),2,max)) ## normalize cols???
        score2 <- sign(score2) * abs(score2/max(abs(score2)))**3   ## fudging
        bmar <- 0 + pmax((50 - nrow(score2))*0.25,0)
        corrplot::corrplot( score2, is.corr=FALSE, cl.pos = "n", col=BLUERED(100),
                 tl.cex = 0.9*cex2, tl.col = "grey20", tl.srt = 90,
                 mar=c(bmar,0,0,0) )
    }
    
    wordcloud_actmap.RENDER %<a-% shiny::reactive({

        cat("<wordcloud_actmap> called\n")
        
        ##df <- enrich_getCurrentWordEnrichment()
        ##req(df)
        res <- enrich_getWordFreqResults()   
        score <- sapply(res$gsea, function(x) x$NES)
        rownames(score) <- res$gsea[[1]]$word
        
        plotWcActmap(
            score = score,
            normalize = input$wc_normalize,
            nterm = 50,
            nfc = 20
        )
                    
    })    

    wordcloud_actmap.RENDER2 %<a-% shiny::reactive({

        cat("<wordcloud_actmap> called\n")
        
        ##df <- enrich_getCurrentWordEnrichment()
        ##req(df)
        res <- enrich_getWordFreqResults()   
        score <- sapply(res$gsea, function(x) x$NES)
        rownames(score) <- res$gsea[[1]]$word
        
        plotWcActmap(
            score = score,
            normalize = input$wc_normalize,
            nterm = 50,
            nfc = 100
        )
                    
    })    

    
    ##---------------------------------------------------------------
    ##------------- modules for WordCloud ---------------------------
    ##---------------------------------------------------------------



    enrich_wordtsne_info = "<strong>Word t-SNE.</strong> T-SNE of keywords that were found in the title/description of gene sets. Keywords that are often found together in title/descriptions are placed close together in the t-SNE. For each keyword we computed enrichment using GSEA on the mean (absolute) enrichment profiles (averaged over all contrasts). Statistically significant gene sets (q<0.05) are colored in red. The sizes of the nodes are proportional to the normalized enrichment score (NES) of the keyword."

    enrich_wordtsne_options = shiny::tagList(
        shinyBS::tipify(shiny::radioButtons(ns("enrich_wordtsne_algo"),"Clustering algorithm:",
                            choices=c("tsne","umap"),inline=TRUE),
               "Choose a clustering algorithm: t-SNE or UMAP.")
    )
    
    shiny::callModule(
        plotModule,
        id = "enrich_wordtsne", label="c", 
        ##plotlib="ggplot", func=enrich_wordtsne.RENDER,
        plotlib="plotly", func=enrich_wordtsne.PLOTLY, 
        info.text = enrich_wordtsne_info,
        options = enrich_wordtsne_options,
        pdf.width=8, pdf.height=8, pdf.pointsize=13,
        height = 0.5*rowH, res=72,
        ##datacsv = enrich_getWordFreq,
        title = "Word t-SNE",
        add.watermark = WATERMARK
    )


    enrich_wordcloud_opts = shiny::tagList(
        shinyBS::tipify(shiny::selectInput(ns("enrich_wordcloud_exclude"),"Exclude words:", choices=NULL, multiple=TRUE),
               "Paste a keyword to exclude it from the plot.", placement="top", options = list(container = "body")),
        shinyBS::tipify(shiny::selectInput(ns("enrich_wordcloud_colors"),"Colors:", choices=c("Blues","Greys","Accent","Dark2"),
                           multiple=FALSE),
               "Choose a set of colors.", placement="top", options = list(container = "body"))
    )

    shiny::callModule(
        plotModule,
        id = "enrich_wordcloud", label="b",
        func = enrich_wordcloud.RENDER, 
        func2 = enrich_wordcloud.RENDER, 
        plotlib="base", renderFunc="renderPlot", outputFunc="plotOutput",
        ##plotlib="htmlwidget", renderFunc="renderWordcloud2", outputFunc="wordcloud2Output",
        ##plotlib="htmlwidget", renderFunc="renderd3Cloud", outputFunc="d3CloudOutput",
        ##download.fmt = NULL,
        info.text = "<strong>Word cloud.</strong> Word cloud of the most enriched keywords for the data set. Select a keyword in the 'Enrichment table'. In the plot settings, users can exclude certain words from the figure, or choose the color palette. The sizes of the words are relative to the normalized enrichment score (NES) from the GSEA computation. Keyword enrichment is computed by running GSEA on the mean (squared) enrichment profile (averaged over all contrasts). For each keyword, we defined the 'keyword set' as the collection of genesets that contain that keyword in the title/description.",
        options = enrich_wordcloud_opts,
        pdf.width=6, pdf.height=6, 
        height = 0.5*rowH, res=72,
        title = "Word cloud",
        add.watermark = WATERMARK
    )

    enrich_gseaplots_info = "<strong>Keyword enrichment analysis.</strong> Computes enrichment of a selected keyword across all contrasts. Select a keyword by clicking a word in the 'Enrichment table'.

<br><br>Keyword enrichment is computed by running GSEA on the enrichment score profile for all contrasts. We defined the test set as the collection of genesets that contain the keyword in the title/description. Black vertical bars indicate the position of gene sets that contains the *keyword* in the ranked list of enrichment scores. The curve in green corresponds to the 'running statistic' of the keyword enrichment score. The more the green ES curve is shifted to the upper left of the graph, the more the keyword is enriched in the first group. Conversely, a shift of the green ES curve to the lower right, corresponds to keyword enrichment in the second group."

    ##myTextInput('enrich_gseaplots_keywords','Keyword:',"cell cycle"),
    enrich_gseaplots_opts = shiny::tagList(
        shinyBS::tipify( shiny::textInput(ns('enrich_gseaplots_keywords'),'Keyword:',"cell cycle"),
               "Paste a keyword such as 'apoptosis', 'replication' or 'cell cycle'.",
               placement="top", options = list(container = "body"))
    )
    ## enrich_gseaplots_opts = shiny::textInput('enrich_gseaplots_keywords','Keyword:',"cell cycle")
    shiny::callModule(
        plotModule,
        id = "enrich_gseaplots", label="a", 
        plotlib = "base",
        func = enrich_gseaplots.RENDER,
        func2 = enrich_gseaplots.RENDER,
        info.text = enrich_gseaplots_info,
        ## options = enrich_gseaplots_opts,
        pdf.width=6, pdf.height=6,
        height = 0.5*rowH, res=90,
        title = "Enrichment plots",
        add.watermark = WATERMARK
    )

    ##--------buttons for enrichment table

    wordcloud_enrichmentTable_info =
        "<b>Keyword enrichment table.</b> This table shows the keyword enrichment statistics for the selected contrast. The enrichment is calculated using GSEA for occurance of the keywork in the ordered list of gene set descriptions."
    
    wordcloud_enrichmentTable <- shiny::callModule(
        tableModule,
        id = "wordcloud_enrichmentTable", label="e",
        func = wordcloud_enrichmentTable.RENDER, 
        info.text = wordcloud_enrichmentTable_info,
        title = "Enrichment table",
        height = c(270,700)
    )

    ##--------buttons for leading edge table
    wordcloud_leadingEdgeTable <- shiny::callModule(
        tableModule,
        id = "wordcloud_leadingEdgeTable", label="f",
        func = wordcloud_leadingEdgeTable.RENDER, 
        info.text="Keyword leading edge table.", 
        title = "Leading-edge table",
        height = c(270,700)
    )

    ##-------- Activation map plotting module
    wordcloud_actmap.opts = shiny::tagList()
    shiny::callModule(
        plotModule,
        id="wordcloud_actmap",
        func = wordcloud_actmap.RENDER,
        func2 = wordcloud_actmap.RENDER2,
        title = "Activation matrix", label="d",
        info.text = "The <strong>Activation Matrix</strong> visualizes the activation of drug activation enrichment across the conditions. The size of the circles correspond to their relative activation, and are colored according to their upregulation (red) or downregulation (blue) in the contrast profile.",
        options = wordcloud_actmap.opts,
        pdf.width=6, pdf.height=10,
        height = c(rowH,750), width=c("100%",1400),
        res=72,
        add.watermark = WATERMARK
    )

    ##---------------------------------------------------------------
    ##-------------- UI Layout for WordCloud ------------------------
    ##---------------------------------------------------------------

    wordcloud_caption = "<b>(a)</b> <b>Word enrichment</b>  plots for the top most significant contrasts. Black vertical bars indicate the position of gene sets, in the ranked enrichment scores, that contains the *keyword*. The green curve corresponds to 'running statistics' of the keyword enrichment score. <b>(b)</b> <b>Word cloud.</b> The size of the words are relative to the normalized enrichment score (NES) from the GSEA computation. <b>(c)</b> <b>Word t-SNE</b> of keywords extracted from the titles/descriptions of the genesets. <b>(d)</b> <b>Activation matrix</b> showing keyword enrichment across contrasts. <b>(e)</b> <b>Enrichment table</b> of keywords for selected contrast. <b>(f)</b> <b>Leading edge terms</b> for selected keyword."

    output$wordcloud_UI <- shiny::renderUI({
        shiny::fillCol(
            height = fullH,
            flex = c(NA,0.035,1),
            shiny::div(shiny::HTML(wordcloud_caption),class="caption"),
            shiny::br(),
            shiny::fillRow(
                height = rowH,
                flex = c(3.8,1),
                shiny::fillCol(
                    flex=c(1.2,0.1,1),
                    height = rowH,
                    shiny::fillRow(
                        flex = c(1.2,0.05,1,0.05,1),
                        plotWidget(ns("enrich_gseaplots")),
                        shiny::br(),
                        plotWidget(ns("enrich_wordcloud")),
                        shiny::br(),
                        ##moduleWidget(enrich_wordtsne_module), 
                        plotWidget(ns("enrich_wordtsne"))
                    ),
                    shiny::br(),
                    shiny::fillRow(
                        flex=c(1,0.08,1),
                        tableWidget(ns("wordcloud_enrichmentTable")),
                        shiny::br(),
                        tableWidget(ns("wordcloud_leadingEdgeTable"))
                    )
                ),
                plotWidget(ns("wordcloud_actmap"))
            )
        )
    })



}

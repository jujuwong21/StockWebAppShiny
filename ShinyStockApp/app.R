#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(tidyverse)
library(shiny)
library(colourpicker)
library(plotly)
library(quantmod)
library(tidyquant)  
library(shinythemes)
library(DT)
library(lubridate)

my_theme <- theme_light() + 
    theme(plot.title = element_text(hjust = 0.5),
          plot.subtitle = element_text(hjust = 0.5),
          legend.position = "none", 
          plot.background = element_rect(fill = "gray95"),
          panel.background = element_rect(fill = "gray98"),
          text = element_text(family = "HersheySans"))

today <- Sys.Date()

# Define UI
ui <- fluidPage(
    theme = shinytheme('darkly'),
    # Colors the hover (background green, text is black)
    tags$head(tags$style(HTML('table.dataTable.hover tbody tr:hover, table.dataTable.display tbody tr:hover {
                              color: #000000 !important; background-color: #04bc8c !important;
                                } '))),
    # Colors the text
    tags$head(tags$style(HTML('table.dataTable tbody tr, table.dataTable.display tbody tr {
                              color: #000000 !important;
                                } '))),
    # Colors the header (text: show entries, etc.)
    tags$style(HTML('.dataTables_wrapper .dataTables_length, .dataTables_wrapper .dataTables_filter, .dataTables_wrapper .dataTables_info, .dataTables_wrapper .dataTables_processing,.dataTables_wrapper .dataTables_paginate .paginate_button, .dataTables_wrapper .dataTables_paginate .paginate_button.disabled {
            color: #ffffff !important;
        }
        .dataTables_length label{
  color: #7f7f7f; }')),
    
    titlePanel('Basic Stock Searcher'),
    sidebarLayout(
        sidebarPanel(
            textInput('stock', 'Type in a ticker symbol', 'AAPL'),
            
            selectInput('date', 'Choose a date range', 
                        choices = c('Custom', 'Last month', 'Last 3 months', 
                                    'Last 6 months', 'Year-to-date', 'Last year', 
                                    'Last 5 years', 'Last 10 years')),
            
            uiOutput('ui'),
            
            selectInput('type', 'Choose a type of plot', choices = c('Line Plot', 'Area Plot', 'Red Green Area')),
            
            #        actionButton(inputId = 'get_data', label = 'Load', 
            #                     icon('rocket'), 
            #                     block = TRUE, 
            #                     style='color: #fff; background-color: #337ab7; border-color: #2e6da4'), 
            
            # Adds extra space
            tags$br(),
            tags$br(),
            
            downloadButton('download_data', label = 'Download Data (CSV)')
        ),
        
        mainPanel(
            tabsetPanel(
                tabPanel(title = 'Plot', plotlyOutput('plot')),
                tabPanel(title = 'Table', dataTableOutput('table'))
            )
        )
    )
)

server <- function(input, output) {
    output$ui <- renderUI({
        if (is.null(input$date))
            return()
        switch(
            input$date, 
            'Custom' = dateRangeInput('daterange', 'Choose a range:',
                                      start  = '2001-01-01',
                                      end    = today,
                                      min    = '2001-01-01',
                                      max    = today,
                                      format = 'mm/dd/yy',
                                      separator = ' - ')
        )
    })
    
    start_time <- reactive({
        case_when(input$date == 'Custom' ~ input$daterange[1],
                  input$date == 'Last month' ~ today - months(1), 
                  input$date == 'Last 3 months'  ~ today - months(3),
                  input$date == 'Last 6 months' ~ today - months(6),
                  input$date == 'Year-to-date' ~ floor_date(today, unit = "year"),
                  input$date == 'Last year'  ~ today - years(1),
                  input$date == 'Last 5 years' ~ today - years(5), 
                  input$date == 'Last 10 years' ~ today - years(10),
                  TRUE ~ input$daterange[2] - 60)
    })
    
    end_time <- reactive({
        case_when(input$date == 'Custom' ~ input$daterange[2],
                  TRUE ~ today)
    })
    
    
    # Filtered data
    filtered_data <- reactive({
        validate(
            need(input$stock != "", "Please type a stock ticker symbol")
        )
        validate(
            need(try(tq_get(input$stock, get = 'stock.prices', 
                            from = Sys.Date() - months(1), to = Sys.Date())), 
                 "Please enter a valid stock ticker")
        )
        
        tq_get(input$stock, 
               get = 'stock.prices', 
               from = start_time(), 
               to = end_time()) 
    })
    
    # Plot type (line, area, red/green)
    plot_after <- reactive({
        filtered_data <- filtered_data()
        if (input$type == 'Line Plot'){
            filtered_data %>%
                ggplot(aes(x = date, y = adjusted)) + 
                geom_line()  
        }
        else if (input$type == 'Area Plot'){
            ggplot <- filtered_data %>%
                ggplot(aes(x = date, y = adjusted)) + 
                geom_area()
        } else{ # Red/Green
            first <- filtered_data[1, 7]
            last <- filtered_data[nrow(filtered_data), 7]
            color <- case_when(first <= last ~ '#04bc8c', 
                               TRUE ~ '#e74c3d')
            
            ggplot <- filtered_data %>%
                ggplot(aes(x = date, y = adjusted)) + 
                geom_area(fill = color)
        }
    })
    
    # Create table
    output$table <- DT::renderDataTable({
        #    input$get_data
        #    isolate({
        datatable(filtered_data() %>%
                      mutate(open = round(open, 2), 
                             high = round(high, 2), 
                             low = round(low, 2), 
                             close = round(close, 2), 
                             adjusted = round(adjusted, 2)) %>%
                      arrange(desc(date)), 
                  rownames = FALSE 
        )}) 
    
    
    # Download CSV
    output$download_data <- downloadHandler(
        filename = 'stock_data.csv',
        content = function(file) {
            data <- filtered_data()
            write.csv(data, file, row.names = FALSE)
        })
    
    # Plot
    output$plot <- renderPlotly({
        #    input$get_data
        #    isolate({
        ggplot <- plot_after() +
            labs(title = paste('Adj. Close for ', toupper(input$stock), 
                               '(', start_time(), ' to ', end_time(), ')'), 
                 x = 'Date', y ='Adjusted Close Price ($)') +
            my_theme
        #      })
    })
}

shinyApp(ui, server)
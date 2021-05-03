library(shiny)
library(tidyr)
library(tidyverse)
library(readxl)
library(writexl)


lista_sklepow <- read_excel(file.path("Z:/PRODUKT/NOWE SKLEPY/aplikacja","lista sklepow.xlsx")) %>%  select(sklepy=4) %>% unique() %>% na.omit() %>%  mutate(sklepy=paste("SKLEP", sklepy)) %>% pull()


shinyUI(fluidPage(
  titlePanel("automatyczne mmki ze sklepu"),
    sidebarLayout(
        sidebarPanel(
              fileInput("co_przesunac_od_nich","wgraj plik z lista do przesuniecia", accept = ".xlsx"),
              actionButton("update","odswiez"),
              numericInput("ilosc_MMek","do ilu sklepow chcesz wysylac", min=1, max=length(lista_sklepow), value=length(lista_sklepow),step=1),
              checkboxGroupInput("nie_przesuwac_do_nich", "wskaz wykluczone sklepy:",
                       choiceNames = lista_sklepow,
                         choiceValues =lista_sklepow),
              selectInput(inputId = "sklep_odtowarowywany","sklep odtowarowywany",choices=lista_sklepow, ""),
              checkboxGroupInput("bez_jeansow", "wskaz sklepy bez jeansow",
                                 choiceNames = lista_sklepow,
                                 choiceValues =lista_sklepow),
              textInput("folder","sciezka do folderu z danymi",value="Z:/PRODUKT/NOWE SKLEPY/algorytm zwrotów pod zatowarowanie"),
              selectInput(inputId = "sposob_sortowania","sposob sortowania",choices=c("po ilosci z indekso rozmiaru rosnaco"="a",
                                                                                      "po sprzedazy na indeksie malejaco"="b",
                                                                                      "po zatowarowaniu rosnaco"="c",
                                                                                      "po ilosci z indeksu rosnaco"="d"), ""),
              selectInput(inputId = "opcja_towarowania","czy chcemy zlecac",choices=c("per rozmiar"="opcja1",
                                                                                      "per indeks"="opcja2"), ""),
              selectInput(inputId = "opcja_dotowarowania","czy sie kierowac dla sklepow, ktore nie maja tego indeksu",
                                                                            choices=c("po zatowarowaniu"="opcjaA",
                                                                                      "po sprzedazy"="opcjaB"), ""),
              downloadButton("upload","pobierz plik")
                    
              ,width = 4),
  mainPanel(tabsetPanel(type="tabs",
                tabPanel("Pelna lista", tableOutput("podsumowanie")),
                tabPanel("Lista ograniczona", tableOutput("podsumowanie_1"))
             )))))



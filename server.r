library(shiny)
library(tidyr)
library(tidyverse)
library(readxl)
library(writexl)




shinyServer(function(input, output,session){

nie_przesuwac_do_nich_lista<-reactive({paste0(c(input$nie_przesuwac_do_nich))})

output$id<-renderText(nie_przesuwac_do_nich_lista())

sklep_odtowarowywany_zmienna <- reactive({input$sklep_odtowarowywany})
 
sklepy_bez_jeansow <- reactive({input$bez_jeansow}) 

co_przesunac_od_nich_zmienna<-reactive({
  inFile <- input$co_przesunac_od_nich
  if(is.null(inFile))
    return(NULL)
  read.csv(inFile$datapath,sep=";") 
})
  
nazwa_folderu <- reactive({input$folder})


###########################################################
#2. przygotowanie zestawienia sklepow do ktorych chcemy to przenosic
#a) remanenty wraz z tym co do nich juz jedzie

remanenty_1<- reactive({
  nazwa_folderu1<-nazwa_folderu()
  remanenty_sklep_folder<-list.files(file.path(nazwa_folderu1,"remanenty"))
  remanenty<-c()
  setwd(file.path(nazwa_folderu1,"remanenty"))
  
  for(i in remanenty_sklep_folder){
    r1<-read_csv2(i)
    remanenty<-rbind(remanenty, r1)
  }
  
  sapply(remanenty[,5:9],as.numeric) ->remanenty[,5:9]
  
  #wybieram jakie chce kolumny i zmieniam im nazwe
  remanenty %>% select(Magazyn=2,KodProduktu=3,Rozmiar=4,ilosc=9) %>%  filter(ilosc>=0) 
})

#teraz doloze informacje o sprzedazy z 30 dni dla danego indeksu w danym sklepie

#b) pobieramy paragony 

paragony<-reactive({
  nazwa_folderu1<-nazwa_folderu()
  list.files(file.path(nazwa_folderu1,"paragony"))->paragony_folder
  read_csv2(paste0(file.path(nazwa_folderu1,"paragony"),"/",paragony_folder)) 
})

#troche je oczyszczamy i dopisujemy czlon "Sklep". Uzyskujemy w ten sposob sprzedaz na indeksie

sprzedaz_na_indeksie<-reactive({
  paragony_A<-paragony()
  paragony_A %>% select(3,6,ILOSC=8) %>% group_by(SKLEP, `KOD PRODUKTU`) %>% summarise(SlsU= sum(ILOSC)) %>% arrange(desc(SlsU)) %>% ungroup() %>% mutate(SKLEP=paste("SKLEP",SKLEP))
})

#chcemy tez sprzedaz na indekso-rozmiarze
sprzedaz_na_indekso_rozmiarze<-reactive({
  paragony_A<-paragony()
  paragony_A %>% select(3,6,7,ILOSC=8) %>% group_by(SKLEP, `KOD PRODUKTU`,ROZMIAR) %>% summarise(SlsU_R= sum(ILOSC)) %>% arrange(desc(SlsU_R)) %>% ungroup()%>% mutate(SKLEP=paste("SKLEP",SKLEP))
})


#c)polskie znaki

polskie_znaki<-reactive({
  nazwa_folderu1<-nazwa_folderu()
  read_xlsx(file.path(nazwa_folderu1,"POLSKIE ZNAKI.xlsx"))
})


# d) pobieramy raporty zatowarowania
# tekstylia

tekstylia<- reactive({
  nazwa_folderu1<-nazwa_folderu()
  list.files(file.path(nazwa_folderu1,"raport zatowarowania"))->raport_zatowarowania_folder
  
  raport_zatowarowania<- read_xlsx(paste0(file.path(nazwa_folderu1,"raport zatowarowania"),"/",raport_zatowarowania_folder),sheet = "pojemności-REAL",skip=1)
  raport_zatowarowania %>% select(SKLEP=2,"1_MĘŻCZYZNA"=12,"2_KOBIETA"=13,"3_CHŁOPAK"=14) %>% filter(!is.na(SKLEP)) %>% gather(DEPARTAMENT,WARTOŚĆ,-1) %>% mutate(KATEGORIA="TEKSTYLIA")
})


#buty 

buty<- reactive({
  nazwa_folderu1<-nazwa_folderu()
  list.files(file.path(nazwa_folderu1,"raport zatowarowania"))->raport_zatowarowania_folder
  
  raport_zatowarowania<- read_xlsx(paste0(file.path(nazwa_folderu1,"raport zatowarowania"),"/",raport_zatowarowania_folder),sheet = "pojemności-REAL",skip=1)
  raport_zatowarowania  %>% select(SKLEP=2,"1_MĘŻCZYZNA"=40,"2_KOBIETA"=41,"3_CHŁOPAK"=42) %>% filter(!is.na(SKLEP)) %>% gather(DEPARTAMENT,WARTOŚĆ,-1) %>% mutate(KATEGORIA="OBUWIE")
})

#jeans

jeans<- reactive({
  nazwa_folderu1<-nazwa_folderu()
  list.files(file.path(nazwa_folderu1,"raport zatowarowania"))->raport_zatowarowania_folder
  
  raport_zatowarowania<- read_xlsx(paste0(file.path(nazwa_folderu1,"raport zatowarowania"),"/",raport_zatowarowania_folder),sheet = "pojemności-REAL",skip=1)
  raport_zatowarowania  %>% select(SKLEP=2,"1_MĘŻCZYZNA"=58) %>% filter(!is.na(SKLEP)) %>% gather(DEPARTAMENT,WARTOŚĆ,-1) %>% mutate(KATEGORIA="TEKSTYLIA", GRUPA="JEANS")
})



##scalmy teraz raporty zatowarowania
raport_zatowarowanie_1<-reactive({
  tekstylia1<-tekstylia()  
  buty1<-buty()
  jeans1<-jeans()
  polskie_znaki1<-polskie_znaki()
  rbind(tekstylia1, buty1) %>% mutate(GRUPA=NA) %>% rbind(jeans1) %>% left_join(polskie_znaki1, by="SKLEP") %>% select(Magazyn=6,2,4,5,3)  %>% 
  mutate(WARTOŚC=as.numeric(WARTOŚĆ),Magazyn=paste("SKLEP",Magazyn))
 
  })

#e) pobieramy hierarchie  

hierarchia_1<-reactive({
  nazwa_folderu1<-nazwa_folderu()
hierarchia<-read_xlsx(file.path(nazwa_folderu1,"HierarchiaProd.xlsx"), sheet = "listaModeli")

#trochÄ™ je oczyszczamy
hierarchia %>% select(KodProduktu=2,KATEGORIA=4,11,12) %>% mutate(GRUPA=toupper(GRUPA))
})

# 4 laczymy dane
# a) najpierw hierarchia z remanentem

baza1_1<-reactive({
  remanenty_1A<-remanenty_1()
  hierarchia_1A<-hierarchia_1()
  remanenty_1A %>%  left_join(hierarchia_1A, by=c("KodProduktu"))
})


#b) potem targety

remanenty_rob_2<- reactive({
  raport_zatowarowanie_1A<-raport_zatowarowanie_1()
  baza1_1A<-baza1_1()
bez_jeansów<-raport_zatowarowanie_1A %>% filter(is.na(GRUPA))
same_jeansy<-raport_zatowarowanie_1A %>% filter(GRUPA=="JEANS")

remanenty_rob_1<-baza1_1A %>% left_join(bez_jeansów, by=c("Magazyn","DEPARTAMENT","KATEGORIA")) %>% select(1:6, GRUPA=7, 10 ) %>% left_join(same_jeansy, by=c("Magazyn","DEPARTAMENT","KATEGORIA", "GRUPA"))

#musimy poprawiÄ‡, bo nam siÄ™ Ĺşle targety sumujÄ….
wartosci<-ifelse(remanenty_rob_1$GRUPA=="JEANS",remanenty_rob_1$WARTOŚC.y,remanenty_rob_1$WARTOŚC.x)

remanenty_rob_1 %>%  mutate(WARTOŚC=wartosci)

})

zestawienie_1<- reactive({
  remanenty_rob_2A<-remanenty_rob_2()
  sprzedaz_na_indeksie_1<-sprzedaz_na_indeksie()
  sprzedaz_na_indekso_rozmiarze_1<-sprzedaz_na_indekso_rozmiarze()

#laczymy tez teraz paragony do tego zbioru (mamy teraz ile danego indeksu dany sklep sprzedawal dopisane do rozmiaru "SLSU, dodamy tez ilosc szt sprzedanych danego indekso rozmiaru SlsU_R
remanenty_rob_2A %>%  select(-c(8:10))  %>%  left_join(sprzedaz_na_indeksie_1, by=c("Magazyn"="SKLEP","KodProduktu"="KOD PRODUKTU")) %>% 
  left_join(sprzedaz_na_indekso_rozmiarze_1, by=c("Magazyn"="SKLEP","KodProduktu"="KOD PRODUKTU", "Rozmiar"="ROZMIAR" ))   ->zestawienie1_1

#wywalmy jeszcze artykuly dla sklepow i NA
zestawienie1_1 %>%  filter(DEPARTAMENT!="ARTYKUŁY DLA SKLEPÓW") %>%  filter(!str_detect(KodProduktu, "KAES")) %>% replace(is.na(.), 0)
})

zestawienie_pomocnicze_1<-reactive({
  zestawienie_1A<-zestawienie_1()

#dodatkowa kolumna ile dany sklep ma ogole tego indeksu
zestawienie_1A %>% group_by(Magazyn, KodProduktu) %>%  summarise(ile_szt_all=sum(ilosc))
})


SLS_SUMA <-reactive({
  zestawienie_1A<- zestawienie_1()
##dodatkowa kolumna ile dany sklep w ogóle sprzedał szt w tygodniu innych indeksów z kategori i depu (dobre do zatowarowania sklepów w nowe indeksy)
  zestawienie_1A %>% group_by(Magazyn, KATEGORIA, DEPARTAMENT) %>%  summarise(SUMA=sum(SlsU_R)) %>% arrange(desc(SUMA)) 
})

wykaz_indekso_rozmiarow <- reactive({
  zestawienie_1A<- zestawienie_1()
##nalezy jeszcze w tabeli uwzglednic sklepy z zerową iloscia danego indekso rozmiaru, bo one potem sa wyzej brane pod uwage.
  zestawienie_1A %>%  group_by(KodProduktu, Rozmiar) %>% summarise(n=n()) %>% mutate(n=1) 
})

dla_slsU_R <- reactive({
  zestawienie_1A<- zestawienie_1()
zestawienie_1A %>%  select(1,2,3,10) })

dla_ilosc<- reactive({
  zestawienie_1A<- zestawienie_1()
  zestawienie_1A %>% select(1,2,3,4)
})

zest.cz.2<-reactive({
  zestawienie_1A<- zestawienie_1()
  zestawienie_pomocnicze_1A<-zestawienie_pomocnicze_1()
  SLS_SUMA_1A<-SLS_SUMA()
  wykaz_indekso_rozmiarow_1A <- wykaz_indekso_rozmiarow()
  dla_ilosc_1A<-dla_ilosc()
  dla_slsU_R_1A<-dla_slsU_R()
  
#doklejamy poprzednio wyliczona dana do tabeli
zestawienie_1A %>% left_join(zestawienie_pomocnicze_1A, by=c("Magazyn","KodProduktu")) %>% left_join(SLS_SUMA_1A, by=c("Magazyn","KATEGORIA","DEPARTAMENT")) %>% 
  full_join(wykaz_indekso_rozmiarow_1A, by=c("KodProduktu")) %>% select(1,2,Rozmiar=13, 4:9,10,11:12) %>% left_join(dla_ilosc_1A,by=c("Magazyn","KodProduktu","Rozmiar")) %>% 
  left_join(dla_slsU_R_1A, by=c("Magazyn","KodProduktu","Rozmiar")) %>%  select(1:3,ilosc=13,5:9,SlsU_R=14,11,12) %>% unique() %>% replace(is.na(.), 0) 
})

wykluczone<-reactive({
  #usuwam z listy sklepy, ktorych niechce dotowarowywac
zest.cz.2_A<-zest.cz.2()
sklep_odtowarowywany_zmienna_1A<-sklep_odtowarowywany_zmienna()
nie_przesuwac_do_nich_lista_1A<-nie_przesuwac_do_nich_lista()
zest.cz.2_A%>%  filter(!Magazyn %in% c(sklep_odtowarowywany_zmienna_1A,nie_przesuwac_do_nich_lista_1A))
})

## i wykonujemy sortowanie, najpierw po kodzie, potem po rozmiarze 
## nastepnie ilosc sprzedanego tego indeksu w ostatnim czasie (malejaco); ilosc sprzedanego rozmiaru w ostatnim czasie (malejaco);
## ilosc szt tego rozmiaru na sklepie (rosnaco);  poziom zatowarowania sklepu w dany asortyment (rosnaco) ; i na koncu dodatkowo rosnaco ile szt tego indeksu jest na tym sklepie
#### mozna sortowac wg roznego klucza /// np jak bedzie duzo MMek, to dac "wartosc" jako drugi czynnik///

posortowane_1<- reactive({
  wykluczone_1A<-wykluczone()
  switch(input$sposob_sortowania,
         "a"=wykluczone_1A %>% arrange(KodProduktu,Rozmiar,ilosc,desc(SlsU_R),desc(SlsU),ile_szt_all,WARTOŚC,desc(SUMA))%>% select(-ile_szt_all),
         "b"=wykluczone_1A %>% arrange(KodProduktu,Rozmiar,desc(SlsU),ilosc,desc(SlsU_R),ile_szt_all,WARTOŚC,desc(SUMA))%>% select(-ile_szt_all), 
         "c"=wykluczone_1A %>% arrange(KodProduktu,Rozmiar,WARTOŚC,ilosc,desc(SlsU_R),desc(SlsU),ile_szt_all,desc(SUMA))%>% select(-ile_szt_all), 
         "d"=wykluczone_1A %>% arrange(KodProduktu,Rozmiar,ile_szt_all,ilosc,desc(SlsU_R),desc(SlsU),ile_szt_all,WARTOŚC,desc(SUMA))%>% select(-ile_szt_all)
  )
})

MMki<- reactive({
  posortowane_1_1A<-posortowane_1()
  co_przesunac_od_nich<-co_przesunac_od_nich_zmienna()
  sklep_odtowarowywany<-sklep_odtowarowywany_zmienna()
  
  if(is.null(co_przesunac_od_nich))
    return(NULL)
  
  switch(input$opcja_towarowania,
         "opcja1"= {posortowane_1_1A %>% group_by(KodProduktu,Rozmiar) %>% slice(1) %>%  select(1,2,3)->lista_biorcow
           str_replace(lista_biorcow$Rozmiar, ",",".")->lista_biorcow$Rozmiar
           left_join(co_przesunac_od_nich, lista_biorcow, by=c("KodProduktu","Rozmiar")) %>%  mutate(skad=sklep_odtowarowywany) %>%  select(KodProduktu,Rozmiar, ilosc,skad,dokad=Magazyn) 
             },
         
         "opcja2"= {posortowane_1_1A %>% group_by(KodProduktu) %>% slice(1) %>%  select(1,2) ->lista_biorcow
                   left_join(co_przesunac_od_nich, lista_biorcow, by="KodProduktu") %>%  mutate(skad=sklep_odtowarowywany) %>%  select(KodProduktu,Rozmiar, ilosc,skad,dokad=Magazyn) 
                   }
  )
})


MMki_scalone<- eventReactive(input$update,{
  posortowane_1_1A<-posortowane_1()
  co_przesunac_od_nich<-co_przesunac_od_nich_zmienna()
  nie_przesuwac_do_nich <- nie_przesuwac_do_nich_lista()
  sklep_odtowarowywany<-sklep_odtowarowywany_zmienna()
  hierarchia_1A<-hierarchia_1()
  zestawienie_1A<-zestawienie_1()
  gdzie_nie_jeansy<-sklepy_bez_jeansow()
  SLS_SUMA_1A<-SLS_SUMA()
  MMki_1A<-MMki()
  
  if(sum(is.na(MMki_1A)) >0){
    switch(input$opcja_towarowania,
           "opcja1"= {posortowane_1_1A %>% group_by(KodProduktu,Rozmiar) %>% slice(1) %>%  select(1,2,3)->lista_biorcow
             left_join(co_przesunac_od_nich, lista_biorcow, by=c("KodProduktu","Rozmiar")) %>%  mutate(skad=sklep_odtowarowywany) %>%  select(KodProduktu,Rozmiar, ilosc,skad,dokad=Magazyn)%>% filter(is.na(dokad)) ->indeksy_na
           },
           "opcja2"= {posortowane_1_1A %>% group_by(KodProduktu) %>% slice(1) %>%  select(1,2) ->lista_biorcow
             left_join(co_przesunac_od_nich, lista_biorcow, by="KodProduktu") %>%  mutate(skad=sklep_odtowarowywany) %>%  select(KodProduktu,Rozmiar, ilosc,skad,dokad=Magazyn)%>% filter(is.na(dokad)) ->indeksy_na        
           })
    #daje im kategoryzacje
    indeksy_na %>% left_join(hierarchia_1A, by=c("KodProduktu")) ->indeksy_do_rozdysponowania
    
    #wskazuje najbardziej niedotowarowany sklep w danej kategorii i departamencie
    ##uwzgledniajac, ze nie kazdy sklep moze miec kazdy towar, np junior czy jeansy. Dla uproszczenia wyklucze wszystkie, bez rozrozniania
    
    switch(input$opcja_dotowarowania,
           "opcjaA"= {zestawienie_1A %>%  select(Magazyn,KATEGORIA,DEPARTAMENT,GRUPA, WARTOŚC) %>%  arrange(WARTOŚC, KATEGORIA, DEPARTAMENT, GRUPA) %>%  unique() %>% 
               filter(!Magazyn %in% c(sklep_odtowarowywany,nie_przesuwac_do_nich,gdzie_nie_jeansy)) %>%
               group_by(KATEGORIA, DEPARTAMENT, GRUPA) %>% slice(1)->dodatkowi_dawcy 
           },
           "opcjaB"= {zestawienie_1A %>% left_join(SLS_SUMA_1A, by=c("Magazyn","KATEGORIA","DEPARTAMENT")) %>% select(Magazyn,KATEGORIA,DEPARTAMENT,GRUPA, SUMA) %>%  
               arrange(desc(SUMA), KATEGORIA, DEPARTAMENT, GRUPA) %>%  unique() %>%  filter(!Magazyn %in% c(sklep_odtowarowywany,nie_przesuwac_do_nich,gdzie_nie_jeansy)) %>%
               group_by(KATEGORIA, DEPARTAMENT, GRUPA) %>% slice(1)->dodatkowi_dawcy })
    left_join(indeksy_do_rozdysponowania, dodatkowi_dawcy, by=c("KATEGORIA","DEPARTAMENT","GRUPA")) %>% select(1,2,3,4,dokad=Magazyn)->MMki_1
    MMki_1 %>% rbind(na.omit(MMki_1A))
    
  }else{
    MMki_1A 
  }
  
})

output$podsumowanie_2 <-renderTable({
  MMki_scalone_1A<-MMki_scalone()
  MMki_scalone_1A %>%  head()})
})

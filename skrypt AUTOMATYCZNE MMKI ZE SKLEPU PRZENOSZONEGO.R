#AUTOMATYCZNE MMKI ZE SKLEPU PRZENOSZONEGO   /obecnie przeniesie produkty tylko do sklepow ktÛre maja jakakolwiek szt. przy akcesoriach moze byc k≥opot
### DOCELOWO, mozna byloby dodac udzial wyprzedazy w danym sklepie, jako element sortowania, i jezeli indeksy bylyby sale to bysmy wsadzali tam gdzie jest jej najmniej)

library(tidyr)
library(tidyverse)
library(xlsx)
library(readxl)
library(writexl)


#1 zdefiniujmy zasady

nie_przesuwac_do_nich<-c("S90","S89")
sklep_odtowarowywany= "SKLEP W£ADYS£AWOWO"
folder<-"Z:/PRODUKT/NOWE SKLEPY/algorytm zwrotÛw pod zatowarowanie"

gdzie_nie_junior<-c("SKLEP RACIB”RZ")
gdzie_nie_jeansy<-c("SKLEP KUTNO", "SKLEP G£OWNO", "STRZELCE OPOLSKIE")


#2. PUNKT wyjcia to dane wyjsciowe ze skryptu sklep przenoszony, a dokladniej plik:
co_przesunac_od_nich<-read_xlsx(file.path(file.path(folder, "zrzuty"),"co_przesunac.xlsx"))


#mamy wiec towar, ktory chcemy od nich zabrac. W kolejnym kroku trzeba wskazac dokad najlepiej je przesunac.

#indeksy te przesunmy do sklepow posortowanych w takiej kolejnosci:
## ilosc sprzedanego tego indeksu w ostatnim czasie (malejaco); ilosc sprzedanego rozmiaru w ostatnim czasie (malejaco);
## ilosc szt tego rozmiaru na sklepie (rosnaco);  poziom zatowarowania sklepu w dany asortyment (rosnaco)

#### oczywiscie tymi zasadami mozna rotowac, zeby zrobic jak najmniej MMek, lub wskazac tylko sklepy, ktÛre rozwazamy.
## ! waøne nie rekomenduje jako pierwszy czynnik poziom zatowarowania, bo wszystko pÛjdzie do kilku sklepÛw.

#3. przygotowanie zestawienia sklepow do ktorych chcemy to przenosic
#a) remanenty wraz z tym co do nich juz jedzie

remanenty_sklep_folder<-list.files(file.path(folder,"remanenty"))
remanenty<-c()
setwd(file.path(folder,"remanenty"))

for(i in remanenty_sklep_folder){
  r1<-read_csv2(i)
  remanenty<-rbind(remanenty, r1)
}

#oczyszczamy troche te dane
sapply(remanenty[,5:9],as.numeric) ->remanenty[,5:9]

#wybieram jakie chce kolumny wykorzystywac i zmieniam im nazwe
remanenty %>% select(Magazyn=2,KodProduktu=3,Rozmiar=4,ilosc=9) %>%  filter(ilosc>=0) ->remanenty_1

#teraz doloze informacje o sprzedazy z 30 dni dla danego indeksu w danym sklepie

#b) poberamy paragony 
list.files(file.path(folder,"paragony"))->paragony_folder

paragony<-read_csv2(paste0(file.path(folder,"paragony"),"/",paragony_folder)) 

#trochÍ je oczyszczamy i dopisujemy czlon "Sklep". Uzyskujemy w ten sposob sprzedaz na indeksie
paragony %>% select(3,6,8) %>% group_by(SKLEP, `KOD PRODUKTU`) %>% summarise(SlsU= sum(ILOå∆)) %>% arrange(desc(SlsU)) %>% ungroup()%>% mutate(SKLEP=paste("SKLEP",SKLEP))->sprzedaz_na_indeksie

#chcemy tez sprzedaz na indekso-rozmiarze
paragony %>% select(3,6,7,8) %>% group_by(SKLEP, `KOD PRODUKTU`,ROZMIAR) %>% summarise(SlsU_R= sum(ILOå∆)) %>% arrange(desc(SlsU_R)) %>% ungroup()%>% mutate(SKLEP=paste("SKLEP",SKLEP))->sprzedaz_na_indekso_rozmiarze

#c)pobieramy plik polskie znaki
polskie_znaki<-read_xlsx(file.path(folder,"POLSKIE ZNAKI.xlsx"))

# d) pobieramy raporty zatowarowania
# tekstylia

list.files(file.path(folder,"raport zatowarowania"))->raport_zatowarowania_folder

raport_zatowarowania<-read_xlsx(paste0(file.path(folder,"raport zatowarowania"),"/",raport_zatowarowania_folder),sheet = "pojemnoúci-REAL",skip=1)

tekstylia<-raport_zatowarowania %>% select(SKLEP=2,"1_M ØCZYZNA"=12,"2_KOBIETA"=13,"3_CH£OPAK"=14) %>% filter(!is.na(SKLEP)) %>% gather(DEPARTAMENT,WARTOå∆,-1) %>% mutate(KATEGORIA="TEKSTYLIA")

#buty 
buty<-raport_zatowarowania %>% select(SKLEP=2,"1_M ØCZYZNA"=40,"2_KOBIETA"=41,"3_CH£OPAK"=42) %>% filter(!is.na(SKLEP)) %>% gather(DEPARTAMENT,WARTOå∆,-1) %>% mutate(KATEGORIA="OBUWIE") 

#jeans
jeans<-raport_zatowarowania %>% select(SKLEP=2,"1_M ØCZYZNA"=58) %>% filter(!is.na(SKLEP)) %>% gather(DEPARTAMENT,WARTOå∆,-1) %>% mutate(KATEGORIA="TEKSTYLIA", GRUPA="JEANS")

##scalmy teraz raporty zatowarowania
raport_zatowarowanie_1<-rbind(tekstylia, buty) %>% mutate(GRUPA=NA) %>% rbind(jeans) %>% left_join(polskie_znaki, by="SKLEP") %>% select(Magazyn=6,2,4,5,3) %>% mutate(WARTOåC=as.numeric(WARTOå∆))

#dopisujemy do raportu czlon "SKLEP "
raport_zatowarowanie_1$Magazyn<-paste("SKLEP",raport_zatowarowanie_1$Magazyn)

#e) pobieramy hierarchie  
hierarchia<-read_xlsx(file.path(folder,"HierarchiaProd.xlsx"), sheet = "listaModeli")

#trochÍ oczyszczamy nasze dane
hierarchia_1<- hierarchia %>% select(KodProduktu=2,KATEGORIA=4,11,12)

#dajemy grupy z duzej liter
hierarchia_1$GRUPA <- hierarchia_1$GRUPA %>% toupper()

# 4 laczymy dane

# a) najpierw hierarchia z remanentem
remanenty_1 %>%  left_join(hierarchia_1, by=c("KodProduktu"))->baza1_1


#b) potem targety
bez_jeansÛw<-raport_zatowarowanie_1 %>% filter(is.na(GRUPA))
same_jeansy<-raport_zatowarowanie_1 %>% filter(GRUPA=="JEANS")

baza1_1 %>% left_join(bez_jeansÛw, by=c("Magazyn","DEPARTAMENT","KATEGORIA")) %>% select(1:6, GRUPA=7, 10 ) %>% left_join(same_jeansy, by=c("Magazyn","DEPARTAMENT","KATEGORIA", "GRUPA"))->remanenty_rob_1

#musimy poprawiÊ, bo nam siÍ üle targety sumujπ.
wartosci<-ifelse(remanenty_rob_1$GRUPA=="JEANS",remanenty_rob_1$WARTOåC.y,remanenty_rob_1$WARTOåC.x)

remanenty_rob_1$WARTOåC<-wartosci

#laczymy tez teraz paragony do tego zbioru (mamy teraz ile danego indeksu dany sklep sprzedawal dopisane do rozmiaru "SLSU, dodamy tez ilosc szt sprzedanych danego indekso rozmiaru SlsU_R
remanenty_rob_1 %>%  select(-c(8:10))  %>%  left_join(sprzedaz_na_indeksie, by=c("Magazyn"="SKLEP","KodProduktu"="KOD PRODUKTU")) %>% 
  left_join(sprzedaz_na_indekso_rozmiarze, by=c("Magazyn"="SKLEP","KodProduktu"="KOD PRODUKTU", "Rozmiar"="ROZMIAR" ))   ->zestawienie1_1

#wywalmy jeszcze artykuly dla sklepow
zestawienie_1<- zestawienie1_1 %>%  filter(DEPARTAMENT!="ARTYKU£Y DLA SKLEP”W") 

#zamiana NA na 0
zestawienie_1[is.na(zestawienie_1)] <- 0

#dodatkowa kolumna ile dany sklep ma ogÛle tego indeksu
zestawienie_1 %>% group_by(Magazyn, KodProduktu) %>%  summarise(ile_szt_all=sum(ilosc)) ->zestawienie_pomocnicze_1

##dodatkowa kolumna ile dany sklep w ogÛle sprzeda≥ szt w tygodniu innych indeksÛw z kategori i depu (dobre do zatowarowania sklepÛw w nowe indeksy)
zestawienie_1 %>% group_by(Magazyn, KATEGORIA, DEPARTAMENT) %>%  summarise(SUMA=sum(SlsU_R)) %>% arrange(desc(SUMA)) -> SLS_SUMA 

##nalezy jeszcze w tabeli uwzglednic sklepy z zerowπ iloscia danego indekso rozmiaru, bo one potem sa wyzej brane pod uwage.
zestawienie_1 %>%  group_by(KodProduktu, Rozmiar) %>% summarise(n=n()) %>% mutate(n=1) ->wykaz_indekso_rozmiarow
#wykaz_sklepow <- zestawienie_1$Magazyn %>%  unique() %>% as.data.frame() %>% select(kol=1) %>% filter(!kol %in% nie_przesuwac_do_nich)   - do opracowania

zestawienie_1 %>%  select(1,2,3,10) -> dla_slsU_R
zestawienie_1 %>%  select(1,2,3,4)-> dla_ilosc


#doklejamy poprzednio wyliczona dana do tabeli i wykonujemy sortowanie, 
##najpierw po kodzie, potem po rozmiarze 
## nastepnie ilosc sprzedanego tego indeksu w ostatnim czasie (malejaco); ilosc sprzedanego rozmiaru w ostatnim czasie (malejaco);
## ilosc szt tego rozmiaru na sklepie (rosnaco);  poziom zatowarowania sklepu w dany asortyment (rosnaco) ; i na koncu dodatkowo rosnaco ile szt tego indeksu jest na tym sklepie
#### mozna sortowac wg roznego klucza /// np jak bedzie duzo MMek, to dac "wartosc" jako drugi czynnik///

zestawienie_1 %>% left_join(zestawienie_pomocnicze_1, by=c("Magazyn","KodProduktu")) %>% left_join(SLS_SUMA, by=c("Magazyn","KATEGORIA","DEPARTAMENT")) %>% 
full_join(wykaz_indekso_rozmiarow, by=c("KodProduktu")) %>% select(1,2,Rozmiar=13, 4:9,10,11:12) ->zest.cz.1


zest.cz.1%>% left_join(dla_ilosc,by=c("Magazyn","KodProduktu","Rozmiar")) %>% 
  left_join(dla_slsU_R, by=c("Magazyn","KodProduktu","Rozmiar")) %>%  select(1:3,ilosc=13,5:9,SlsU_R=14,11,12) %>% unique()->zest.cz.2

#zamiana NAs przed sortowaniem
zest.cz.2[is.na(zest.cz.2)] <- 0

zest.cz.2 %>% arrange(KodProduktu,Rozmiar,ilosc,desc(SlsU_R),desc(SlsU),ile_szt_all,WARTOåC,desc(SUMA))%>% select(-ile_szt_all) ->posortowane_1

#usuwam z listy sklepy, ktorych niechce dotowarowywac
posortowane_1 %>%  filter(!Magazyn %in% c(sklep_odtowarowywany,nie_przesuwac_do_nich))->posortowane_11


#5 teraz wyznaczymy ostateczna liste biorcow z przesuniec.

#????pytanie czy chce dorzucac do sklepow ilosci do wskazanej granicy ze slownika, czy szybka akcja i mniej MMek, wiec cala ilosc do najlepszego sklepu?
#jezeli tak to tabele posortowane_1 ograniczam tylko do pierwszego wystapienia indekso rozmiaru, tym samym mam odfiltrowane tylko po 1 sklepie z indeko rozmiaru [nie wdrozone na razie, to tylko pomysl]

####################################################### nalezy wybrac rozne opcje

# [opcja 1] rozwiazanie jeøeli chce wysylac kazdy rozmiar tam gdzie trzeba
# [opcja 2] jezeli chcialbym sie skupic na wysylce calego indeksu do wytypowanego miasta.

#wybierz 1 lub 2
opcja=1

#######################################################

if(opcja==1){
  posortowane_11 %>% group_by(KodProduktu,Rozmiar) %>% slice(1) %>%  select(1,2,3)->lista_biorcow
  str_replace(lista_biorcow$Rozmiar, ",",".")->lista_biorcow$Rozmiar #zamiana rozmiarÛw z przecinkiem na kropke
  
  # przeniesienie zabranych ilosci na wskazany sklep
  left_join(co_przesunac_od_nich, lista_biorcow, by=c("KodProduktu","Rozmiar")) %>%  mutate(skad=sklep_odtowarowywany) %>%  select(KodProduktu,Rozmiar, ilosc,skad,dokad=Magazyn) ->MMki
}else if(opcja==2){
  #dla opcji 2 moge zmienic sortowanie, np na takie zestawienie_1 %>% left_join(zestawienie_pomocnicze_1, by=c("Magazyn","KodProduktu")) %>% arrange(KodProduktu,Rozmiar,desc(SlsU),ile_szt_all,WARTOåC)%>% select(-ile_szt_all) ->posortowane_1
  ### posortowane_1 %>%  filter(!Magazyn %in% c(sklep_odtowarowywany,nie_przesuwac_do_nich))->posortowane_11
  posortowane_11 %>% group_by(KodProduktu) %>% slice(1) %>%  select(1,2)->lista_biorcow
  
  # przeniesienie zabranych ilosci na wskazany sklep
  left_join(co_przesunac_od_nich, lista_biorcow, by="KodProduktu") %>%  mutate(skad=sklep_odtowarowywany) %>%  select(KodProduktu,Rozmiar, ilosc,skad,dokad=Magazyn) ->MMki
  
} else{
  print("wybierz opcje 1 lub 2")
}


#7 podsumowanie
MMki %>%  group_by(dokad) %>%  summarise(ilosc_szt=sum(ilosc)) %>% arrange(desc(ilosc_szt)) %>% View()



# 7a dzialanie gdy pojawiaja sie NA, znaczy, ze zaden sklep nie mial tego indeksu (1 to znaczy ze sa NA)

if(sum(is.na(MMki %>%  group_by(dokad) %>%  summarise(ilosc_szt=sum(ilosc)) %>% arrange(desc(ilosc_szt))))==1){
  if(opcja==1){
    left_join(co_przesunac_od_nich, lista_biorcow, by=c("KodProduktu","Rozmiar")) %>%  mutate(skad=sklep_odtowarowywany) %>%  select(KodProduktu,Rozmiar, ilosc,skad,dokad=Magazyn)%>% filter(is.na(dokad)) ->indeksy_na
  }else{
    left_join(co_przesunac_od_nich, lista_biorcow, by="KodProduktu") %>%  mutate(skad=sklep_odtowarowywany) %>%  select(KodProduktu,Rozmiar, ilosc,skad,dokad=Magazyn)%>% filter(is.na(dokad)) ->indeksy_na
  }
#przypisuje indeksom kategoryzacje
indeksy_na %>% left_join(hierarchia_1, by=c("KodProduktu"))  %>%  filter(KATEGORIA!= "ARTYKU£Y DLA SKLEP”W")->indeksy_do_rozdysponowania
}else{
  print("!!! brak na, przejdz dalej")
}

####################################################### nalezy wybrac rozne opcje 

#moge przesunac ten towar albo do najbardziej niedotowarowanego sklepu albo tego co najlepiej sprzedaje
# 1= niedotowarowany
# 2= najlepsza sprzedaz
##uwzgledniajac, ze nie kazdy sklep moze miec kazdy towar, np junior czy jeansy. Dla uproszczenia wyklucze wszystkie, bez rozrozniania  

opcja_1=1
#######################################################

if(opcja_1==1){
  zestawienie1_1 %>%  select(Magazyn,KATEGORIA,DEPARTAMENT,GRUPA, WARTOåC) %>%  arrange(WARTOåC, KATEGORIA, DEPARTAMENT, GRUPA) %>%  unique() %>% 
    filter(!Magazyn %in% c(sklep_odtowarowywany,nie_przesuwac_do_nich,gdzie_nie_jeansy,gdzie_nie_junior)) %>%
    group_by(KATEGORIA, DEPARTAMENT, GRUPA) %>% slice(1)->dodatkowi_dawcy
  
    #rozdysponowuje te indeksy NA
    left_join(indeksy_do_rozdysponowania, dodatkowi_dawcy, by=c("KATEGORIA","DEPARTAMENT","GRUPA")) %>% select(1,2,3,4,dokad=Magazyn)->MMki_1
   
    #scalam zarowno te poprawnie wczesniej rozdysponowane jaki i te teraz wskazane MMki
    rbind(MMki_1, na.omit(MMki))->MMki_scalone
    
} else if (opcja_1==2){
  zestawienie1_1 %>% left_join(SLS_SUMA, by=c("Magazyn","KATEGORIA","DEPARTAMENT")) %>% select(Magazyn,KATEGORIA,DEPARTAMENT,GRUPA, SUMA) %>%  arrange(desc(SUMA), KATEGORIA, DEPARTAMENT, GRUPA) %>%  unique() %>%
    filter(!Magazyn %in% c(sklep_odtowarowywany,nie_przesuwac_do_nich,gdzie_nie_jeansy,gdzie_nie_junior)) %>%
    group_by(KATEGORIA, DEPARTAMENT, GRUPA) %>% slice(1)->dodatkowi_dawcy

    #rozdysponowuje te indeksy NA
    left_join(indeksy_do_rozdysponowania, dodatkowi_dawcy, by=c("KATEGORIA","DEPARTAMENT","GRUPA")) %>% select(1,2,3,4,dokad=Magazyn)->MMki_1
    
    #scalam zarowno te poprawnie wczesniej rozdysponowane jaki i te teraz wskazane MMki
    rbind(MMki_1, na.omit(MMki))->MMki_scalone
    
    } else {
  print("wybierz opcje 1 lub 2")
}



#7a podsumowanie
MMki_scalone %>%  group_by(dokad) %>%  summarise(ilosc_szt=sum(ilosc)) %>% arrange(desc(ilosc_szt)) ->podsumowanie_bez_NA
 View(podsumowanie_bez_NA)


#7b chce ograniczyc ilosc sklepow, ktore dostaja MMek

do_ilu_sklepow<-25

podsumowanie_bez_NA[1:(do_ilu_sklepow),1] %>% pull ->lista_do_ktorych_ostatecznie_przesune

setwd(file.path(folder, "skrypty"))

source("skrypt_ograniczajacy.R", encoding = "UTF-8")

#8 ostateczne podsumowanie

MMki_scalone %>%  group_by(dokad) %>%  summarise(ilosc_szt=sum(ilosc)) %>% arrange(desc(ilosc_szt)) ->podsumowanie_bez_NA
View(podsumowanie_bez_NA)


####################### jeszcze nie wykorzystywane.
#8zlecenie do sklepow (masowe) ~~!!! potem dostosowac jak System zmieni narzÍdzie

MMki_scalone %>% select(1,2,3,"SKLEP èR”D£OWY"=4, "MAGAZYN WIRTUALNY DOCELOWY"=5) 


#9 podzia≥ na osobne pliki z 1 sklepu do rÛønych !!!
docelowy<- MMki_scalone[,5] %>%  unique() %>%  pull() # lub zamiast pull  %>% as.character()    w sytuacji gdy plik wejsciowy bedzie oryginalnie csv a nie recznie zapisany

#zmieniamy nazwÍ folderu
setwd("Z:/PRODUKT/NOWE SKLEPY/algorytm zwrotÛw pod zatowarowanie/mmki/w≥adys≥awowo")

for (i in docelowy){
  j<-filter(MMki_scalone,dokad==i) %>%  select(1,2,3)
  write_xlsx(j,paste0(i,".xlsx"))
}


######TESTUJEMY CZY ILOSCI NA SKLEPY S• OK 


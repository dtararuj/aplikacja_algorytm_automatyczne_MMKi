## skrypt, ktory ograniczy ilosc sklepow, ktore maja dostac MMki do wprowadzonej liczby


#usuwam z listy sklepy, ktorych niechce dotowarowywac (dokladam te,ktore sa ponad ponad liczba dopuszczalnych MMek)
posortowane_1 %>%  filter(!Magazyn %in% c(sklep_odtowarowywany,nie_przesuwac_do_nich)) %>%  filter(Magazyn %in% lista_do_ktorych_ostatecznie_przesune)->posortowane_11

# teraz wyznaczymy ostateczna liste biorcow z przesuniec. (tu dopuszczam tylko po indekso-rozmiarze, bo mniej sklepow, na pewno sie uda)

posortowane_11 %>% group_by(KodProduktu,Rozmiar) %>% slice(1) %>%  select(1,2,3)->lista_biorcow

#zamiana rozmiarów z przecinkiem na kropke 
str_replace(lista_biorcow$Rozmiar, ",",".")->lista_biorcow$Rozmiar

# przeniesienie zabranych ilosci na wskazany sklep
left_join(co_przesunac_od_nich, lista_biorcow, by=c("KodProduktu","Rozmiar")) %>%  mutate(skad=sklep_odtowarowywany) %>%  select(KodProduktu,Rozmiar, ilosc,skad,dokad=Magazyn) ->MMki

#wyszukuje indeksy, ktore nie maja pary

left_join(co_przesunac_od_nich, lista_biorcow, by=c("KodProduktu","Rozmiar")) %>%  mutate(skad=sklep_odtowarowywany) %>%  select(KodProduktu,Rozmiar, ilosc,skad,dokad=Magazyn)%>% filter(is.na(dokad)) ->indeksy_na

####################################################################################################

#daje im kategoryzacje
indeksy_na %>% left_join(hierarchia_1, by=c("KodProduktu"))  %>%  filter(KATEGORIA!= "ARTYKUŁY DLA SKLEPÓW")->indeksy_do_rozdysponowania

#wskazuje najbardziej niedotowarowany sklep w danej kategorii i departamencie
##uwzgledniajac, ze nie kazdy sklep moze miec kazdy towar, np junior czy jeansy. Dla uproszczenia wyklucze wszystkie, bez rozrozniania

#################opcja 1 po wartosci - niedotowarowany dostaje towar 
zestawienie1_1 %>%  select(Magazyn,KATEGORIA,DEPARTAMENT,GRUPA, WARTOŚC) %>%  arrange(WARTOŚC, KATEGORIA, DEPARTAMENT, GRUPA) %>%  unique() %>% 
  filter(!Magazyn %in% c(sklep_odtowarowywany,nie_przesuwac_do_nich,gdzie_nie_jeansy,gdzie_nie_junior) & Magazyn %in% lista_do_ktorych_ostatecznie_przesune) %>%
  group_by(KATEGORIA, DEPARTAMENT, GRUPA) %>% slice(1)->dodatkowi_dawcy


################opcja 2 po ilosci sprzedazy całkowitej danego sklepu 

### zestawienie1_1 %>% left_join(SLS_SUMA, by=c("Magazyn","KATEGORIA","DEPARTAMENT")) %>% select(Magazyn,KATEGORIA,DEPARTAMENT,GRUPA, SUMA) %>%  arrange(desc(SUMA), KATEGORIA, DEPARTAMENT, GRUPA) %>%  unique() %>%  filter(!Magazyn %in% c(sklep_odtowarowywany,nie_przesuwac_do_nich,gdzie_nie_jeansy,gdzie_nie_junior)) %>% group_by(KATEGORIA, DEPARTAMENT, GRUPA) %>% slice(1)->dodatkowi_dawcy

######################################################################################################


#rozdysponowuje te indeksy NA
left_join(indeksy_do_rozdysponowania, dodatkowi_dawcy, by=c("KATEGORIA","DEPARTAMENT","GRUPA")) %>% select(1,2,3,4,dokad=Magazyn)->MMki_1

# scalam zarowno te poprawnie wczesniej rozdysponowane jak i te teraz wskazane
rbind(MMki_1, na.omit(MMki))->MMki_scalone



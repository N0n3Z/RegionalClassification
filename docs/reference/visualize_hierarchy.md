# Visualize the hierarchy of a specific classification

Shows the tree structure of levels within a classification.

## Usage

``` r
visualize_hierarchy(classification, master_data, max_communes = 3)
```

## Arguments

- classification:

  "NIS_2019", "NIS_2025", or "NUTS_2021"

- master_data:

  Output from build_master_table()

- max_communes:

  Maximum communes to show per arrondissement (default 3)

## Value

Character string (tree representation), printed to console

## Examples

``` r
# \donttest{
  master_data <- load_master_data()
#> Master data loaded from 'C:/Users/Dell/AppData/Local/Temp/RtmpQNI466/temp_libpath2a8447f11d6b/nbbbenuts/extdata': 581 communes NIS 2019, 565 NIS 2025, 589 NIS BEFORE_2019
  visualize_hierarchy("NIS_2019",  master_data)
#> 
#> Region: RÉGION DE BRUXELLES-CAPITALE (4000)
#>   +-- Province: RÉGION DE BRUXELLES-CAPITALE (4000)
#>       +-- Arr: Arrondissement de Bruxelles-Capitale (21000)
#>           |-- Anderlecht (21001)
#>           |-- Auderghem (21002)
#>           |-- Berchem-Sainte-Agathe (21003)
#>           +-- ... et 16 autres communes
#> Region: RÉGION FLAMANDE (2000)
#>   |-- Province: Province d'Anvers (10000)
#>   |   |-- Arr: Arrondissement d'Anvers (11000)
#>   |   |   |-- Aartselaar (11001)
#>   |   |   |-- Anvers (11002)
#>   |   |   |-- Boechout (11004)
#>   |   |   +-- ... et 27 autres communes
#>   |   |-- Arr: Arrondissement de Malines (12000)
#>   |   |   |-- Berlaar (12002)
#>   |   |   |-- Bonheiden (12005)
#>   |   |   |-- Bornem (12007)
#>   |   |   +-- ... et 9 autres communes
#>   |   +-- Arr: Arrondissement de Turnhout (13000)
#>   |       |-- Arendonk (13001)
#>   |       |-- Baerle-Duc (13002)
#>   |       |-- Balen (13003)
#>   |       +-- ... et 24 autres communes
#>   |-- Province: Province du Limbourg (70000)
#>   |   |-- Arr: Arrondissement de Tongres (73000)
#>   |   |   |-- Alken (73001)
#>   |   |   |-- Bilzen (73006)
#>   |   |   |-- Looz (73009)
#>   |   |   +-- ... et 10 autres communes
#>   |   |-- Arr: Arrondissement de Hasselt (71000)
#>   |   |   |-- As (71002)
#>   |   |   |-- Beringen (71004)
#>   |   |   |-- Diepenbeek (71011)
#>   |   |   +-- ... et 14 autres communes
#>   |   +-- Arr: Arrondissement de Maaseik (72000)
#>   |       |-- Bocholt (72003)
#>   |       |-- Bree (72004)
#>   |       |-- Kinrooi (72018)
#>   |       +-- ... et 9 autres communes
#>   |-- Province: Province de Flandre Orientale (40000)
#>   |   |-- Arr: Arrondissement d'Alost (41000)
#>   |   |   |-- Alost (41002)
#>   |   |   |-- Denderleeuw (41011)
#>   |   |   |-- Grammont (41018)
#>   |   |   +-- ... et 7 autres communes
#>   |   |-- Arr: Arrondissement de Termonde (42000)
#>   |   |   |-- Berlare (42003)
#>   |   |   |-- Buggenhout (42004)
#>   |   |   |-- Termonde (42006)
#>   |   |   +-- ... et 7 autres communes
#>   |   |-- Arr: Arrondissement d'Eeklo (43000)
#>   |   |   |-- Assenede (43002)
#>   |   |   |-- Eeklo (43005)
#>   |   |   |-- Kaprijke (43007)
#>   |   |   +-- ... et 3 autres communes
#>   |   |-- Arr: Arrondissement de Gand (44000)
#>   |   |   |-- De Pinte (44012)
#>   |   |   |-- Destelbergen (44013)
#>   |   |   |-- Evergem (44019)
#>   |   |   +-- ... et 14 autres communes
#>   |   |-- Arr: Arrondissement d'Audenarde (45000)
#>   |   |   |-- Audenarde (45035)
#>   |   |   |-- Renaix (45041)
#>   |   |   |-- Brakel (45059)
#>   |   |   +-- ... et 7 autres communes
#>   |   +-- Arr: Arrondissement de Saint-Nicolas (46000)
#>   |       |-- Beveren (46003)
#>   |       |-- Kruibeke (46013)
#>   |       |-- Lokeren (46014)
#>   |       +-- ... et 4 autres communes
#>   |-- Province: Province du Brabant Flamand (20001)
#>   |   |-- Arr: Arrondissement de Hal-Vilvorde (23000)
#>   |   |   |-- Asse (23002)
#>   |   |   |-- Beersel (23003)
#>   |   |   |-- Biévène (23009)
#>   |   |   +-- ... et 32 autres communes
#>   |   +-- Arr: Arrondissement de Louvain (24000)
#>   |       |-- Aarschot (24001)
#>   |       |-- Begijnendijk (24007)
#>   |       |-- Bekkevoort (24008)
#>   |       +-- ... et 27 autres communes
#>   +-- Province: Province de Flandre Occidentale (30000)
#>       |-- Arr: Arrondissement de Bruges (31000)
#>       |   |-- Beernem (31003)
#>       |   |-- Blankenberge (31004)
#>       |   |-- Bruges (31005)
#>       |   +-- ... et 7 autres communes
#>       |-- Arr: Arrondissement de Dixmude (32000)
#>       |   |-- Dixmude (32003)
#>       |   |-- Houthulst (32006)
#>       |   |-- Koekelare (32010)
#>       |   +-- ... et 2 autres communes
#>       |-- Arr: Arrondissement d'Ypres (33000)
#>       |   |-- Ypres (33011)
#>       |   |-- Messines (33016)
#>       |   |-- Poperinge (33021)
#>       |   +-- ... et 5 autres communes
#>       |-- Arr: Arrondissement de Courtrai (34000)
#>       |   |-- Anzegem (34002)
#>       |   |-- Avelgem (34003)
#>       |   |-- Deerlijk (34009)
#>       |   +-- ... et 9 autres communes
#>       |-- Arr: Arrondissement d'Ostende (35000)
#>       |   |-- Bredene (35002)
#>       |   |-- Gistel (35005)
#>       |   |-- Ichtegem (35006)
#>       |   +-- ... et 4 autres communes
#>       |-- Arr: Arrondissement de Roulers (36000)
#>       |   |-- Hooglede (36006)
#>       |   |-- Ingelmunster (36007)
#>       |   |-- Izegem (36008)
#>       |   +-- ... et 5 autres communes
#>       |-- Arr: Arrondissement de Tielt (37000)
#>       |   |-- Dentergem (37002)
#>       |   |-- Meulebeke (37007)
#>       |   |-- Oostrozebeke (37010)
#>       |   +-- ... et 6 autres communes
#>       +-- Arr: Arrondissement de Furnes (38000)
#>           |-- Alveringem (38002)
#>           |-- La Panne (38008)
#>           |-- Koksijde (38014)
#>           +-- ... et 2 autres communes
#> Region: RÉGION WALLONNE (3000)
#>   |-- Province: Province du Brabant Wallon (20002)
#>   |   +-- Arr: Arrondissement de Nivelles (25000)
#>   |       |-- Beauvechain (25005)
#>   |       |-- Braine-l'Alleud (25014)
#>   |       |-- Braine-le-Château (25015)
#>   |       +-- ... et 24 autres communes
#>   |-- Province: Province du Hainaut (50000)
#>   |   |-- Arr: Arrondissement de Mons (53000)
#>   |   |   |-- Boussu (53014)
#>   |   |   |-- Dour (53020)
#>   |   |   |-- Frameries (53028)
#>   |   |   +-- ... et 10 autres communes
#>   |   |-- Arr: Arrondissement de Tournai-Mouscron (57000)
#>   |   |   |-- Antoing (57003)
#>   |   |   |-- Celles (57018)
#>   |   |   |-- Estaimpuis (57027)
#>   |   |   +-- ... et 9 autres communes
#>   |   |-- Arr: Arrondissement de La Louvière (58000)
#>   |   |   |-- La Louvière (58001)
#>   |   |   |-- Binche (58002)
#>   |   |   |-- Estinnes (58003)
#>   |   |   +-- ... et 1 autres communes
#>   |   |-- Arr: Arrondissement d'Ath (51000)
#>   |   |   |-- Ath (51004)
#>   |   |   |-- Beloeil (51008)
#>   |   |   |-- Bernissart (51009)
#>   |   |   +-- ... et 8 autres communes
#>   |   |-- Arr: Arrondissement de Charleroi (52000)
#>   |   |   |-- Chapelle-lez-Herlaimont (52010)
#>   |   |   |-- Charleroi (52011)
#>   |   |   |-- Châtelet (52012)
#>   |   |   +-- ... et 9 autres communes
#>   |   |-- Arr: Arrondissement de Soignies (55000)
#>   |   |   |-- Braine-le-Comte (55004)
#>   |   |   |-- Le Roeulx (55035)
#>   |   |   |-- Soignies (55040)
#>   |   |   +-- ... et 3 autres communes
#>   |   +-- Arr: Arrondissement de Thuin (56000)
#>   |       |-- Anderlues (56001)
#>   |       |-- Beaumont (56005)
#>   |       |-- Chimay (56016)
#>   |       +-- ... et 8 autres communes
#>   |-- Province: Province de Liège (60000)
#>   |   |-- Arr: Arrondissement de Huy (61000)
#>   |   |   |-- Amay (61003)
#>   |   |   |-- Burdinne (61010)
#>   |   |   |-- Clavier (61012)
#>   |   |   +-- ... et 14 autres communes
#>   |   |-- Arr: Arrondissement de Liège (62000)
#>   |   |   |-- Ans (62003)
#>   |   |   |-- Awans (62006)
#>   |   |   |-- Aywaille (62009)
#>   |   |   +-- ... et 21 autres communes
#>   |   |-- Arr: Arrondissement de Waremme (64000)
#>   |   |   |-- Berloz (64008)
#>   |   |   |-- Braives (64015)
#>   |   |   |-- Crisnée (64021)
#>   |   |   +-- ... et 11 autres communes
#>   |   +-- Arr: Arrondissement de Verviers (63000)
#>   |       |-- Aubel (63003)
#>   |       |-- Baelen (63004)
#>   |       |-- Dison (63020)
#>   |       +-- ... et 26 autres communes
#>   |-- Province: Province du Luxembourg (80000)
#>   |   |-- Arr: Arrondissement d'Arlon (81000)
#>   |   |   |-- Arlon (81001)
#>   |   |   |-- Attert (81003)
#>   |   |   |-- Aubange (81004)
#>   |   |   +-- ... et 2 autres communes
#>   |   |-- Arr: Arrondissement de Bastogne (82000)
#>   |   |   |-- Bastogne (82003)
#>   |   |   |-- Bertogne (82005)
#>   |   |   |-- Fauvillers (82009)
#>   |   |   +-- ... et 5 autres communes
#>   |   |-- Arr: Arrondissement de Marche-en-Famenne (83000)
#>   |   |   |-- Durbuy (83012)
#>   |   |   |-- Erezée (83013)
#>   |   |   |-- Hotton (83028)
#>   |   |   +-- ... et 6 autres communes
#>   |   |-- Arr: Arrondissement de Neufchâteau (84000)
#>   |   |   |-- Bertrix (84009)
#>   |   |   |-- Bouillon (84010)
#>   |   |   |-- Daverdisse (84016)
#>   |   |   +-- ... et 9 autres communes
#>   |   +-- Arr: Arrondissement de Virton (85000)
#>   |       |-- Chiny (85007)
#>   |       |-- Etalle (85009)
#>   |       |-- Florenville (85011)
#>   |       +-- ... et 7 autres communes
#>   +-- Province: Province de Namur (90000)
#>       |-- Arr: Arrondissement de Dinant (91000)
#>       |   |-- Anhée (91005)
#>       |   |-- Beauraing (91013)
#>       |   |-- Bièvre (91015)
#>       |   +-- ... et 12 autres communes
#>       |-- Arr: Arrondissement de Namur (92000)
#>       |   |-- Andenne (92003)
#>       |   |-- Assesse (92006)
#>       |   |-- Eghezée (92035)
#>       |   +-- ... et 13 autres communes
#>       +-- Arr: Arrondissement de Philippeville (93000)
#>           |-- Cerfontaine (93010)
#>           |-- Couvin (93014)
#>           |-- Doische (93018)
#>           +-- ... et 4 autres communes
  visualize_hierarchy("NIS_2025",  master_data)
#> 
#> Region: RÉGION FLAMANDE (2000)
#>   |-- Province: Province d'Anvers (10000)
#>   |   |-- Arr: Arrondissement d'Anvers (11000)
#>   |   |   |-- Aartselaar (11001)
#>   |   |   |-- Anvers (11002)
#>   |   |   |-- Boechout (11004)
#>   |   |   +-- ... et 25 autres communes
#>   |   |-- Arr: Arrondissement de Malines (12000)
#>   |   |   |-- Berlaar (12002)
#>   |   |   |-- Bonheiden (12005)
#>   |   |   |-- Bornem (12007)
#>   |   |   +-- ... et 9 autres communes
#>   |   +-- Arr: Arrondissement de Turnhout (13000)
#>   |       |-- Arendonk (13001)
#>   |       |-- Baerle-Duc (13002)
#>   |       |-- Balen (13003)
#>   |       +-- ... et 24 autres communes
#>   |-- Province: Province du Brabant Flamand (20001)
#>   |   |-- Arr: Arrondissement de Hal-Vilvorde (23000)
#>   |   |   |-- Asse (23002)
#>   |   |   |-- Beersel (23003)
#>   |   |   |-- Biévène (23009)
#>   |   |   +-- ... et 30 autres communes
#>   |   +-- Arr: Arrondissement de Louvain (24000)
#>   |       |-- Aarschot (24001)
#>   |       |-- Begijnendijk (24007)
#>   |       |-- Bekkevoort (24008)
#>   |       +-- ... et 27 autres communes
#>   |-- Province: Province de Flandre Occidentale (30000)
#>   |   |-- Arr: Arrondissement de Bruges (31000)
#>   |   |   |-- Beernem (31003)
#>   |   |   |-- Blankenberge (31004)
#>   |   |   |-- Bruges (31005)
#>   |   |   +-- ... et 7 autres communes
#>   |   |-- Arr: Arrondissement de Dixmude (32000)
#>   |   |   |-- Dixmude (32003)
#>   |   |   |-- Houthulst (32006)
#>   |   |   |-- Koekelare (32010)
#>   |   |   +-- ... et 2 autres communes
#>   |   |-- Arr: Arrondissement d'Ypres (33000)
#>   |   |   |-- Ypres (33011)
#>   |   |   |-- Messines (33016)
#>   |   |   |-- Poperinge (33021)
#>   |   |   +-- ... et 5 autres communes
#>   |   |-- Arr: Arrondissement de Courtrai (34000)
#>   |   |   |-- Anzegem (34002)
#>   |   |   |-- Avelgem (34003)
#>   |   |   |-- Deerlijk (34009)
#>   |   |   +-- ... et 9 autres communes
#>   |   |-- Arr: Arrondissement d'Ostende (35000)
#>   |   |   |-- Bredene (35002)
#>   |   |   |-- Gistel (35005)
#>   |   |   |-- Ichtegem (35006)
#>   |   |   +-- ... et 4 autres communes
#>   |   |-- Arr: Arrondissement de Roulers (36000)
#>   |   |   |-- Hooglede (36006)
#>   |   |   |-- Ingelmunster (36007)
#>   |   |   |-- Izegem (36008)
#>   |   |   +-- ... et 5 autres communes
#>   |   |-- Arr: Arrondissement de Tielt (37000)
#>   |   |   |-- Dentergem (37002)
#>   |   |   |-- Oostrozebeke (37010)
#>   |   |   |-- Pittem (37011)
#>   |   |   +-- ... et 4 autres communes
#>   |   +-- Arr: Arrondissement de Furnes (38000)
#>   |       |-- Alveringem (38002)
#>   |       |-- La Panne (38008)
#>   |       |-- Koksijde (38014)
#>   |       +-- ... et 2 autres communes
#>   |-- Province: Province de Flandre Orientale (40000)
#>   |   |-- Arr: Arrondissement d'Alost (41000)
#>   |   |   |-- Alost (41002)
#>   |   |   |-- Denderleeuw (41011)
#>   |   |   |-- Grammont (41018)
#>   |   |   +-- ... et 7 autres communes
#>   |   |-- Arr: Arrondissement de Termonde (42000)
#>   |   |   |-- Berlare (42003)
#>   |   |   |-- Buggenhout (42004)
#>   |   |   |-- Termonde (42006)
#>   |   |   +-- ... et 7 autres communes
#>   |   |-- Arr: Arrondissement d'Eeklo (43000)
#>   |   |   |-- Assenede (43002)
#>   |   |   |-- Eeklo (43005)
#>   |   |   |-- Kaprijke (43007)
#>   |   |   +-- ... et 3 autres communes
#>   |   |-- Arr: Arrondissement de Gand (44000)
#>   |   |   |-- Destelbergen (44013)
#>   |   |   |-- Evergem (44019)
#>   |   |   |-- Gavere (44020)
#>   |   |   +-- ... et 10 autres communes
#>   |   |-- Arr: Arrondissement d'Audenarde (45000)
#>   |   |   |-- Audenarde (45035)
#>   |   |   |-- Renaix (45041)
#>   |   |   |-- Brakel (45059)
#>   |   |   +-- ... et 7 autres communes
#>   |   +-- Arr: Arrondissement de Saint-Nicolas (46000)
#>   |       |-- Sint-Gillis-Waas (46020)
#>   |       |-- Saint-Nicolas (46021)
#>   |       |-- Stekene (46024)
#>   |       +-- ... et 3 autres communes
#>   +-- Province: Province du Limbourg (70000)
#>       |-- Arr: Arrondissement de Hasselt (71000)
#>       |   |-- As (71002)
#>       |   |-- Beringen (71004)
#>       |   |-- Diepenbeek (71011)
#>       |   +-- ... et 13 autres communes
#>       |-- Arr: Arrondissement de Maaseik (72000)
#>       |   |-- Bocholt (72003)
#>       |   |-- Bree (72004)
#>       |   |-- Kinrooi (72018)
#>       |   +-- ... et 9 autres communes
#>       +-- Arr: Arrondissement de Tongres (73000)
#>           |-- Alken (73001)
#>           |-- Heers (73022)
#>           |-- Herstappe (73028)
#>           +-- ... et 7 autres communes
#> Region: RÉGION DE BRUXELLES-CAPITALE (4000)
#>   +-- Province: RÉGION DE BRUXELLES-CAPITALE (4000)
#>       +-- Arr: Arrondissement de Bruxelles-Capitale (21000)
#>           |-- Anderlecht (21001)
#>           |-- Auderghem (21002)
#>           |-- Berchem-Sainte-Agathe (21003)
#>           +-- ... et 16 autres communes
#> Region: RÉGION WALLONNE (3000)
#>   |-- Province: Province du Brabant Wallon (20002)
#>   |   +-- Arr: Arrondissement de Nivelles (25000)
#>   |       |-- Beauvechain (25005)
#>   |       |-- Braine-l'Alleud (25014)
#>   |       |-- Braine-le-Château (25015)
#>   |       +-- ... et 24 autres communes
#>   |-- Province: Province du Hainaut (50000)
#>   |   |-- Arr: Arrondissement d'Ath (51000)
#>   |   |   |-- Ath (51004)
#>   |   |   |-- Beloeil (51008)
#>   |   |   |-- Bernissart (51009)
#>   |   |   +-- ... et 8 autres communes
#>   |   |-- Arr: Arrondissement de Charleroi (52000)
#>   |   |   |-- Chapelle-lez-Herlaimont (52010)
#>   |   |   |-- Charleroi (52011)
#>   |   |   |-- Châtelet (52012)
#>   |   |   +-- ... et 9 autres communes
#>   |   |-- Arr: Arrondissement de Mons (53000)
#>   |   |   |-- Boussu (53014)
#>   |   |   |-- Dour (53020)
#>   |   |   |-- Frameries (53028)
#>   |   |   +-- ... et 10 autres communes
#>   |   |-- Arr: Arrondissement de Soignies (55000)
#>   |   |   |-- Braine-le-Comte (55004)
#>   |   |   |-- Le Roeulx (55035)
#>   |   |   |-- Soignies (55040)
#>   |   |   +-- ... et 3 autres communes
#>   |   |-- Arr: Arrondissement de Thuin (56000)
#>   |   |   |-- Anderlues (56001)
#>   |   |   |-- Beaumont (56005)
#>   |   |   |-- Chimay (56016)
#>   |   |   +-- ... et 8 autres communes
#>   |   |-- Arr: Arrondissement de Tournai-Mouscron (57000)
#>   |   |   |-- Antoing (57003)
#>   |   |   |-- Celles (57018)
#>   |   |   |-- Estaimpuis (57027)
#>   |   |   +-- ... et 9 autres communes
#>   |   +-- Arr: Arrondissement de La Louvière (58000)
#>   |       |-- La Louvière (58001)
#>   |       |-- Binche (58002)
#>   |       |-- Estinnes (58003)
#>   |       +-- ... et 1 autres communes
#>   |-- Province: Province de Liège (60000)
#>   |   |-- Arr: Arrondissement de Huy (61000)
#>   |   |   |-- Amay (61003)
#>   |   |   |-- Burdinne (61010)
#>   |   |   |-- Clavier (61012)
#>   |   |   +-- ... et 14 autres communes
#>   |   |-- Arr: Arrondissement de Liège (62000)
#>   |   |   |-- Ans (62003)
#>   |   |   |-- Awans (62006)
#>   |   |   |-- Aywaille (62009)
#>   |   |   +-- ... et 21 autres communes
#>   |   |-- Arr: Arrondissement de Verviers (63000)
#>   |   |   |-- Amblève (63001)
#>   |   |   |-- Aubel (63003)
#>   |   |   |-- Baelen (63004)
#>   |   |   +-- ... et 26 autres communes
#>   |   +-- Arr: Arrondissement de Waremme (64000)
#>   |       |-- Berloz (64008)
#>   |       |-- Braives (64015)
#>   |       |-- Crisnée (64021)
#>   |       +-- ... et 11 autres communes
#>   |-- Province: Province du Luxembourg (80000)
#>   |   |-- Arr: Arrondissement d'Arlon (81000)
#>   |   |   |-- Arlon (81001)
#>   |   |   |-- Attert (81003)
#>   |   |   |-- Aubange (81004)
#>   |   |   +-- ... et 2 autres communes
#>   |   |-- Arr: Arrondissement de Bastogne (82000)
#>   |   |   |-- Fauvillers (82009)
#>   |   |   |-- Houffalize (82014)
#>   |   |   |-- Vielsalm (82032)
#>   |   |   +-- ... et 4 autres communes
#>   |   |-- Arr: Arrondissement de Marche-en-Famenne (83000)
#>   |   |   |-- Durbuy (83012)
#>   |   |   |-- Erezée (83013)
#>   |   |   |-- Hotton (83028)
#>   |   |   +-- ... et 6 autres communes
#>   |   |-- Arr: Arrondissement de Neufchâteau (84000)
#>   |   |   |-- Bertrix (84009)
#>   |   |   |-- Bouillon (84010)
#>   |   |   |-- Daverdisse (84016)
#>   |   |   +-- ... et 9 autres communes
#>   |   +-- Arr: Arrondissement de Virton (85000)
#>   |       |-- Chiny (85007)
#>   |       |-- Etalle (85009)
#>   |       |-- Florenville (85011)
#>   |       +-- ... et 7 autres communes
#>   +-- Province: Province de Namur (90000)
#>       |-- Arr: Arrondissement de Dinant (91000)
#>       |   |-- Anhée (91005)
#>       |   |-- Beauraing (91013)
#>       |   |-- Bièvre (91015)
#>       |   +-- ... et 12 autres communes
#>       |-- Arr: Arrondissement de Namur (92000)
#>       |   |-- Andenne (92003)
#>       |   |-- Assesse (92006)
#>       |   |-- Eghezée (92035)
#>       |   +-- ... et 13 autres communes
#>       +-- Arr: Arrondissement de Philippeville (93000)
#>           |-- Cerfontaine (93010)
#>           |-- Couvin (93014)
#>           |-- Doische (93018)
#>           +-- ... et 4 autres communes
  visualize_hierarchy("NUTS_2021", master_data)
#> 
#> NUTS 2021 Hierarchy (Belgium)
#> BE (Belgique/Belgie)
#>   |-- BE1
#>   |   |-- BE10
#>   |   |   |-- BE100 Arrondissement de Bruxelles-Capitale
#>   |   |   |   |-- 21001 Anderlecht (NIS: 21001)
#>   |   |   |   |-- 21002 Auderghem (NIS: 21002)
#>   |   |   |   |-- 21003 Berchem-Sainte-Agathe (NIS: 21003)
#>   |   |   |   +-- ... et 16 autres
#>   |-- BE2
#>   |   |-- BE21
#>   |   |   |-- BE211 Arrondissement d’Anvers
#>   |   |   |   |-- 11001 Aartselaar (NIS: 11001)
#>   |   |   |   |-- 11002 Anvers (NIS: 11002)
#>   |   |   |   |-- 11004 Boechout (NIS: 11004)
#>   |   |   |   +-- ... et 27 autres
#>   |   |   |-- BE212 Arrondissement de Malines
#>   |   |   |   |-- 12002 Berlaar (NIS: 12002)
#>   |   |   |   |-- 12005 Bonheiden (NIS: 12005)
#>   |   |   |   |-- 12007 Bornem (NIS: 12007)
#>   |   |   |   +-- ... et 9 autres
#>   |   |   |-- BE213 Arrondissement de Turnhout
#>   |   |   |   |-- 13001 Arendonk (NIS: 13001)
#>   |   |   |   |-- 13002 Baerle-Duc (NIS: 13002)
#>   |   |   |   |-- 13003 Balen (NIS: 13003)
#>   |   |   |   +-- ... et 24 autres
#>   |   |-- BE22
#>   |   |   |-- BE223 Arrondissement de Tongres
#>   |   |   |   |-- 73001 Alken (NIS: 73001)
#>   |   |   |   |-- 73006 Bilzen (NIS: 73006)
#>   |   |   |   |-- 73009 Looz (NIS: 73009)
#>   |   |   |   +-- ... et 10 autres
#>   |   |   |-- BE224 Arrondissement de Hasselt
#>   |   |   |   |-- 71002 As (NIS: 71002)
#>   |   |   |   |-- 71004 Beringen (NIS: 71004)
#>   |   |   |   |-- 71011 Diepenbeek (NIS: 71011)
#>   |   |   |   +-- ... et 14 autres
#>   |   |   |-- BE225 Arrondissement de Maaseik
#>   |   |   |   |-- 72003 Bocholt (NIS: 72003)
#>   |   |   |   |-- 72004 Bree (NIS: 72004)
#>   |   |   |   |-- 72018 Kinrooi (NIS: 72018)
#>   |   |   |   +-- ... et 9 autres
#>   |   |-- BE23
#>   |   |   |-- BE231 Arrondissement d’Alost
#>   |   |   |   |-- 41002 Alost (NIS: 41002)
#>   |   |   |   |-- 41011 Denderleeuw (NIS: 41011)
#>   |   |   |   |-- 41018 Grammont (NIS: 41018)
#>   |   |   |   +-- ... et 7 autres
#>   |   |   |-- BE232 Arrondissement de Termonde
#>   |   |   |   |-- 42003 Berlare (NIS: 42003)
#>   |   |   |   |-- 42004 Buggenhout (NIS: 42004)
#>   |   |   |   |-- 42006 Termonde (NIS: 42006)
#>   |   |   |   +-- ... et 7 autres
#>   |   |   |-- BE233 Arrondissement d’Eeklo
#>   |   |   |   |-- 43002 Assenede (NIS: 43002)
#>   |   |   |   |-- 43005 Eeklo (NIS: 43005)
#>   |   |   |   |-- 43007 Kaprijke (NIS: 43007)
#>   |   |   |   +-- ... et 3 autres
#>   |   |   |-- BE234 Arrondissement de Gand
#>   |   |   |   |-- 44012 De Pinte (NIS: 44012)
#>   |   |   |   |-- 44013 Destelbergen (NIS: 44013)
#>   |   |   |   |-- 44019 Evergem (NIS: 44019)
#>   |   |   |   +-- ... et 14 autres
#>   |   |   |-- BE235 Arrondissement d’Audenarde
#>   |   |   |   |-- 45035 Audenarde (NIS: 45035)
#>   |   |   |   |-- 45041 Renaix (NIS: 45041)
#>   |   |   |   |-- 45059 Brakel (NIS: 45059)
#>   |   |   |   +-- ... et 7 autres
#>   |   |   |-- BE236 Arrondissement de Saint-Nicolas
#>   |   |   |   |-- 46003 Beveren (NIS: 46003)
#>   |   |   |   |-- 46013 Kruibeke (NIS: 46013)
#>   |   |   |   |-- 46014 Lokeren (NIS: 46014)
#>   |   |   |   +-- ... et 4 autres
#>   |   |-- BE24
#>   |   |   |-- BE241 Arrondissement de Hal-Vilvorde
#>   |   |   |   |-- 23002 Asse (NIS: 23002)
#>   |   |   |   |-- 23003 Beersel (NIS: 23003)
#>   |   |   |   |-- 23009 Biévène (NIS: 23009)
#>   |   |   |   +-- ... et 32 autres
#>   |   |   |-- BE242 Arrondissement de Louvain
#>   |   |   |   |-- 24001 Aarschot (NIS: 24001)
#>   |   |   |   |-- 24007 Begijnendijk (NIS: 24007)
#>   |   |   |   |-- 24008 Bekkevoort (NIS: 24008)
#>   |   |   |   +-- ... et 27 autres
#>   |   |-- BE25
#>   |   |   |-- BE251 Arrondissement de Bruges
#>   |   |   |   |-- 31003 Beernem (NIS: 31003)
#>   |   |   |   |-- 31004 Blankenberge (NIS: 31004)
#>   |   |   |   |-- 31005 Bruges (NIS: 31005)
#>   |   |   |   +-- ... et 7 autres
#>   |   |   |-- BE252 Arrondissement de Dixmude
#>   |   |   |   |-- 32003 Dixmude (NIS: 32003)
#>   |   |   |   |-- 32006 Houthulst (NIS: 32006)
#>   |   |   |   |-- 32010 Koekelare (NIS: 32010)
#>   |   |   |   +-- ... et 2 autres
#>   |   |   |-- BE253 Arrondissement d’Ypres
#>   |   |   |   |-- 33011 Ypres (NIS: 33011)
#>   |   |   |   |-- 33016 Messines (NIS: 33016)
#>   |   |   |   |-- 33021 Poperinge (NIS: 33021)
#>   |   |   |   +-- ... et 5 autres
#>   |   |   |-- BE254 Arrondissement de Courtrai
#>   |   |   |   |-- 34002 Anzegem (NIS: 34002)
#>   |   |   |   |-- 34003 Avelgem (NIS: 34003)
#>   |   |   |   |-- 34009 Deerlijk (NIS: 34009)
#>   |   |   |   +-- ... et 9 autres
#>   |   |   |-- BE255 Arrondissement d’Ostende
#>   |   |   |   |-- 35002 Bredene (NIS: 35002)
#>   |   |   |   |-- 35005 Gistel (NIS: 35005)
#>   |   |   |   |-- 35006 Ichtegem (NIS: 35006)
#>   |   |   |   +-- ... et 4 autres
#>   |   |   |-- BE256 Arrondissement de Roulers
#>   |   |   |   |-- 36006 Hooglede (NIS: 36006)
#>   |   |   |   |-- 36007 Ingelmunster (NIS: 36007)
#>   |   |   |   |-- 36008 Izegem (NIS: 36008)
#>   |   |   |   +-- ... et 5 autres
#>   |   |   |-- BE257 Arrondissement de Tielt
#>   |   |   |   |-- 37002 Dentergem (NIS: 37002)
#>   |   |   |   |-- 37007 Meulebeke (NIS: 37007)
#>   |   |   |   |-- 37010 Oostrozebeke (NIS: 37010)
#>   |   |   |   +-- ... et 6 autres
#>   |   |   |-- BE258 Arrondissement de Furnes
#>   |   |   |   |-- 38002 Alveringem (NIS: 38002)
#>   |   |   |   |-- 38008 La Panne (NIS: 38008)
#>   |   |   |   |-- 38014 Koksijde (NIS: 38014)
#>   |   |   |   +-- ... et 2 autres
#>   |-- BE3
#>   |   |-- BE31
#>   |   |   |-- BE310 Arrondissement de Nivelles
#>   |   |   |   |-- 25005 Beauvechain (NIS: 25005)
#>   |   |   |   |-- 25014 Braine-l'Alleud (NIS: 25014)
#>   |   |   |   |-- 25015 Braine-le-Château (NIS: 25015)
#>   |   |   |   +-- ... et 24 autres
#>   |   |-- BE32
#>   |   |   |-- BE323 Arrondissement de Mons
#>   |   |   |   |-- 53014 Boussu (NIS: 53014)
#>   |   |   |   |-- 53020 Dour (NIS: 53020)
#>   |   |   |   |-- 53028 Frameries (NIS: 53028)
#>   |   |   |   +-- ... et 10 autres
#>   |   |   |-- BE328 Arrondissement de Tournai-Mouscron
#>   |   |   |   |-- 57003 Antoing (NIS: 57003)
#>   |   |   |   |-- 57018 Celles (NIS: 57018)
#>   |   |   |   |-- 57027 Estaimpuis (NIS: 57027)
#>   |   |   |   +-- ... et 9 autres
#>   |   |   |-- BE329 Arrondissement de La Louvière
#>   |   |   |   |-- 58001 La Louvière (NIS: 58001)
#>   |   |   |   |-- 58002 Binche (NIS: 58002)
#>   |   |   |   |-- 58003 Estinnes (NIS: 58003)
#>   |   |   |   +-- ... et 1 autres
#>   |   |   |-- BE32A Arrondissement d’Ath
#>   |   |   |   |-- 51004 Ath (NIS: 51004)
#>   |   |   |   |-- 51008 Beloeil (NIS: 51008)
#>   |   |   |   |-- 51009 Bernissart (NIS: 51009)
#>   |   |   |   +-- ... et 8 autres
#>   |   |   |-- BE32B Arrondissement de Charleroi
#>   |   |   |   |-- 52010 Chapelle-lez-Herlaimont (NIS: 52010)
#>   |   |   |   |-- 52011 Charleroi (NIS: 52011)
#>   |   |   |   |-- 52012 Châtelet (NIS: 52012)
#>   |   |   |   +-- ... et 9 autres
#>   |   |   |-- BE32C Arrondissement de Soignies
#>   |   |   |   |-- 55004 Braine-le-Comte (NIS: 55004)
#>   |   |   |   |-- 55035 Le Roeulx (NIS: 55035)
#>   |   |   |   |-- 55040 Soignies (NIS: 55040)
#>   |   |   |   +-- ... et 3 autres
#>   |   |   |-- BE32D Arrondissement de Thuin
#>   |   |   |   |-- 56001 Anderlues (NIS: 56001)
#>   |   |   |   |-- 56005 Beaumont (NIS: 56005)
#>   |   |   |   |-- 56016 Chimay (NIS: 56016)
#>   |   |   |   +-- ... et 8 autres
#>   |   |-- BE33
#>   |   |   |-- BE331 Arrondissement de Huy
#>   |   |   |   |-- 61003 Amay (NIS: 61003)
#>   |   |   |   |-- 61010 Burdinne (NIS: 61010)
#>   |   |   |   |-- 61012 Clavier (NIS: 61012)
#>   |   |   |   +-- ... et 14 autres
#>   |   |   |-- BE332 Arrondissement de Liège
#>   |   |   |   |-- 62003 Ans (NIS: 62003)
#>   |   |   |   |-- 62006 Awans (NIS: 62006)
#>   |   |   |   |-- 62009 Aywaille (NIS: 62009)
#>   |   |   |   +-- ... et 21 autres
#>   |   |   |-- BE334 Arrondissement de Waremme
#>   |   |   |   |-- 64008 Berloz (NIS: 64008)
#>   |   |   |   |-- 64015 Braives (NIS: 64015)
#>   |   |   |   |-- 64021 Crisnée (NIS: 64021)
#>   |   |   |   +-- ... et 11 autres
#>   |   |   |-- BE335 Arrondissement de Verviers - Communes francophones
#>   |   |   |   |-- 63003 Aubel (NIS: 63003)
#>   |   |   |   |-- 63004 Baelen (NIS: 63004)
#>   |   |   |   |-- 63020 Dison (NIS: 63020)
#>   |   |   |   +-- ... et 17 autres
#>   |   |   |-- BE336 Arrondissement de Verviers - Communes germanophones
#>   |   |   |   |-- 63001 Amblève (NIS: 63001)
#>   |   |   |   |-- 63012 Bullange (NIS: 63012)
#>   |   |   |   |-- 63013 Butgenbach (NIS: 63013)
#>   |   |   |   +-- ... et 6 autres
#>   |   |-- BE34
#>   |   |   |-- BE341 Arrondissement d’Arlon
#>   |   |   |   |-- 81001 Arlon (NIS: 81001)
#>   |   |   |   |-- 81003 Attert (NIS: 81003)
#>   |   |   |   |-- 81004 Aubange (NIS: 81004)
#>   |   |   |   +-- ... et 2 autres
#>   |   |   |-- BE342 Arrondissement de Bastogne
#>   |   |   |   |-- 82003 Bastogne (NIS: 82003)
#>   |   |   |   |-- 82005 Bertogne (NIS: 82005)
#>   |   |   |   |-- 82009 Fauvillers (NIS: 82009)
#>   |   |   |   +-- ... et 5 autres
#>   |   |   |-- BE343 Arrondissement de Marche-en-Famenne
#>   |   |   |   |-- 83012 Durbuy (NIS: 83012)
#>   |   |   |   |-- 83013 Erezée (NIS: 83013)
#>   |   |   |   |-- 83028 Hotton (NIS: 83028)
#>   |   |   |   +-- ... et 6 autres
#>   |   |   |-- BE344 Arrondissement de Neufchâteau
#>   |   |   |   |-- 84009 Bertrix (NIS: 84009)
#>   |   |   |   |-- 84010 Bouillon (NIS: 84010)
#>   |   |   |   |-- 84016 Daverdisse (NIS: 84016)
#>   |   |   |   +-- ... et 9 autres
#>   |   |   |-- BE345 Arrondissement de Virton
#>   |   |   |   |-- 85007 Chiny (NIS: 85007)
#>   |   |   |   |-- 85009 Etalle (NIS: 85009)
#>   |   |   |   |-- 85011 Florenville (NIS: 85011)
#>   |   |   |   +-- ... et 7 autres
#>   |   |-- BE35
#>   |   |   |-- BE351 Arrondissement de Dinant
#>   |   |   |   |-- 91005 Anhée (NIS: 91005)
#>   |   |   |   |-- 91013 Beauraing (NIS: 91013)
#>   |   |   |   |-- 91015 Bièvre (NIS: 91015)
#>   |   |   |   +-- ... et 12 autres
#>   |   |   |-- BE352 Arrondissement de Namur
#>   |   |   |   |-- 92003 Andenne (NIS: 92003)
#>   |   |   |   |-- 92006 Assesse (NIS: 92006)
#>   |   |   |   |-- 92035 Eghezée (NIS: 92035)
#>   |   |   |   +-- ... et 13 autres
#>   |   |   |-- BE353 Arrondissement de Philippeville
#>   |   |   |   |-- 93010 Cerfontaine (NIS: 93010)
#>   |   |   |   |-- 93014 Couvin (NIS: 93014)
#>   |   |   |   |-- 93018 Doische (NIS: 93018)
#>   |   |   |   +-- ... et 4 autres
# }
```

# Visualize the conversion feasibility matrix as a heatmap

Visualize the conversion feasibility matrix as a heatmap

## Usage

``` r
visualize_conversion_matrix(output_file = NULL)
```

## Arguments

- output_file:

  Optional: save plot to file

## Value

ggplot object if ggplot2 available, otherwise text matrix

## Examples

``` r
# \donttest{
  visualize_conversion_matrix()
#> Package 'ggplot2' not installed. Showing text matrix.
#> Key: <from>
#>                             from NBB_DISTRICT_2021 NIS_COUNTRY
#>                           <char>            <lgcl>      <lgcl>
#>  1:            NBB_DISTRICT_2021              TRUE        TRUE
#>  2:                  NIS_COUNTRY             FALSE        TRUE
#>  3:            NIS_DISTRICT_2019             FALSE        TRUE
#>  4:            NIS_DISTRICT_2025             FALSE        TRUE
#>  5:     NIS_DISTRICT_BEFORE_2019             FALSE        TRUE
#>  6:        NIS_MUNICIPALITY_2019              TRUE        TRUE
#>  7:        NIS_MUNICIPALITY_2025              TRUE        TRUE
#>  8: NIS_MUNICIPALITY_BEFORE_2019              TRUE        TRUE
#>  9:            NIS_PROVINCE_2019             FALSE        TRUE
#> 10:            NIS_PROVINCE_2025             FALSE        TRUE
#> 11:     NIS_PROVINCE_BEFORE_2019             FALSE        TRUE
#> 12:              NIS_REGION_2019             FALSE        TRUE
#> 13:              NIS_REGION_2025             FALSE        TRUE
#> 14:       NIS_REGION_BEFORE_2019             FALSE        TRUE
#> 15:                 NUTS_COUNTRY             FALSE       FALSE
#> 16:           NUTS_DISTRICT_2021              TRUE        TRUE
#> 17:           NUTS_DISTRICT_2027             FALSE       FALSE
#> 18:       NUTS_MUNICIPALITY_2021              TRUE        TRUE
#> 19:           NUTS_PROVINCE_2021             FALSE       FALSE
#> 20:           NUTS_PROVINCE_2027             FALSE       FALSE
#> 21:             NUTS_REGION_2021             FALSE       FALSE
#> 22:             NUTS_REGION_2027             FALSE       FALSE
#> 23:                       POSTAL              TRUE        TRUE
#>                             from NBB_DISTRICT_2021 NIS_COUNTRY
#>                           <char>            <lgcl>      <lgcl>
#>     NIS_DISTRICT_2019 NIS_DISTRICT_2025 NIS_DISTRICT_BEFORE_2019
#>                <lgcl>            <lgcl>                   <lgcl>
#>  1:              TRUE             FALSE                    FALSE
#>  2:             FALSE             FALSE                    FALSE
#>  3:              TRUE             FALSE                    FALSE
#>  4:             FALSE              TRUE                    FALSE
#>  5:             FALSE             FALSE                     TRUE
#>  6:              TRUE              TRUE                    FALSE
#>  7:              TRUE              TRUE                    FALSE
#>  8:              TRUE              TRUE                     TRUE
#>  9:             FALSE             FALSE                    FALSE
#> 10:             FALSE             FALSE                    FALSE
#> 11:             FALSE             FALSE                    FALSE
#> 12:             FALSE             FALSE                    FALSE
#> 13:             FALSE             FALSE                    FALSE
#> 14:             FALSE             FALSE                    FALSE
#> 15:             FALSE             FALSE                    FALSE
#> 16:              TRUE             FALSE                    FALSE
#> 17:             FALSE             FALSE                    FALSE
#> 18:              TRUE              TRUE                    FALSE
#> 19:             FALSE             FALSE                    FALSE
#> 20:             FALSE             FALSE                    FALSE
#> 21:             FALSE             FALSE                    FALSE
#> 22:             FALSE             FALSE                    FALSE
#> 23:              TRUE              TRUE                    FALSE
#>     NIS_DISTRICT_2019 NIS_DISTRICT_2025 NIS_DISTRICT_BEFORE_2019
#>                <lgcl>            <lgcl>                   <lgcl>
#>     NIS_MUNICIPALITY_2019 NIS_MUNICIPALITY_2025 NIS_MUNICIPALITY_BEFORE_2019
#>                    <lgcl>                <lgcl>                       <lgcl>
#>  1:                 FALSE                 FALSE                        FALSE
#>  2:                 FALSE                 FALSE                        FALSE
#>  3:                 FALSE                 FALSE                        FALSE
#>  4:                 FALSE                 FALSE                        FALSE
#>  5:                 FALSE                 FALSE                        FALSE
#>  6:                  TRUE                  TRUE                        FALSE
#>  7:                 FALSE                  TRUE                        FALSE
#>  8:                  TRUE                  TRUE                         TRUE
#>  9:                 FALSE                 FALSE                        FALSE
#> 10:                 FALSE                 FALSE                        FALSE
#> 11:                 FALSE                 FALSE                        FALSE
#> 12:                 FALSE                 FALSE                        FALSE
#> 13:                 FALSE                 FALSE                        FALSE
#> 14:                 FALSE                 FALSE                        FALSE
#> 15:                 FALSE                 FALSE                        FALSE
#> 16:                 FALSE                 FALSE                        FALSE
#> 17:                 FALSE                 FALSE                        FALSE
#> 18:                  TRUE                  TRUE                        FALSE
#> 19:                 FALSE                 FALSE                        FALSE
#> 20:                 FALSE                 FALSE                        FALSE
#> 21:                 FALSE                 FALSE                        FALSE
#> 22:                 FALSE                 FALSE                        FALSE
#> 23:                  TRUE                  TRUE                        FALSE
#>     NIS_MUNICIPALITY_2019 NIS_MUNICIPALITY_2025 NIS_MUNICIPALITY_BEFORE_2019
#>                    <lgcl>                <lgcl>                       <lgcl>
#>     NIS_PROVINCE_2019 NIS_PROVINCE_2025 NIS_PROVINCE_BEFORE_2019
#>                <lgcl>            <lgcl>                   <lgcl>
#>  1:              TRUE             FALSE                    FALSE
#>  2:             FALSE             FALSE                    FALSE
#>  3:              TRUE             FALSE                    FALSE
#>  4:             FALSE              TRUE                    FALSE
#>  5:             FALSE             FALSE                     TRUE
#>  6:              TRUE              TRUE                    FALSE
#>  7:              TRUE              TRUE                    FALSE
#>  8:              TRUE              TRUE                     TRUE
#>  9:              TRUE             FALSE                    FALSE
#> 10:             FALSE              TRUE                    FALSE
#> 11:             FALSE             FALSE                     TRUE
#> 12:             FALSE             FALSE                    FALSE
#> 13:             FALSE             FALSE                    FALSE
#> 14:             FALSE             FALSE                    FALSE
#> 15:             FALSE             FALSE                    FALSE
#> 16:              TRUE             FALSE                    FALSE
#> 17:             FALSE             FALSE                    FALSE
#> 18:              TRUE              TRUE                    FALSE
#> 19:             FALSE             FALSE                    FALSE
#> 20:             FALSE             FALSE                    FALSE
#> 21:             FALSE             FALSE                    FALSE
#> 22:             FALSE             FALSE                    FALSE
#> 23:              TRUE              TRUE                    FALSE
#>     NIS_PROVINCE_2019 NIS_PROVINCE_2025 NIS_PROVINCE_BEFORE_2019
#>                <lgcl>            <lgcl>                   <lgcl>
#>     NIS_REGION_2019 NIS_REGION_2025 NIS_REGION_BEFORE_2019 NUTS_COUNTRY
#>              <lgcl>          <lgcl>                 <lgcl>       <lgcl>
#>  1:            TRUE           FALSE                  FALSE         TRUE
#>  2:           FALSE           FALSE                  FALSE        FALSE
#>  3:            TRUE           FALSE                  FALSE        FALSE
#>  4:           FALSE            TRUE                  FALSE        FALSE
#>  5:           FALSE           FALSE                   TRUE        FALSE
#>  6:            TRUE            TRUE                  FALSE         TRUE
#>  7:            TRUE            TRUE                  FALSE         TRUE
#>  8:            TRUE            TRUE                   TRUE         TRUE
#>  9:            TRUE           FALSE                  FALSE        FALSE
#> 10:           FALSE            TRUE                  FALSE        FALSE
#> 11:           FALSE           FALSE                   TRUE        FALSE
#> 12:            TRUE           FALSE                  FALSE        FALSE
#> 13:           FALSE            TRUE                  FALSE        FALSE
#> 14:           FALSE           FALSE                   TRUE        FALSE
#> 15:           FALSE           FALSE                  FALSE         TRUE
#> 16:            TRUE           FALSE                  FALSE         TRUE
#> 17:           FALSE           FALSE                  FALSE         TRUE
#> 18:            TRUE            TRUE                  FALSE         TRUE
#> 19:           FALSE           FALSE                  FALSE         TRUE
#> 20:           FALSE           FALSE                  FALSE         TRUE
#> 21:           FALSE           FALSE                  FALSE         TRUE
#> 22:           FALSE           FALSE                  FALSE         TRUE
#> 23:            TRUE            TRUE                  FALSE         TRUE
#>     NIS_REGION_2019 NIS_REGION_2025 NIS_REGION_BEFORE_2019 NUTS_COUNTRY
#>              <lgcl>          <lgcl>                 <lgcl>       <lgcl>
#>     NUTS_DISTRICT_2021 NUTS_DISTRICT_2027 NUTS_MUNICIPALITY_2021
#>                 <lgcl>             <lgcl>                 <lgcl>
#>  1:               TRUE              FALSE                  FALSE
#>  2:              FALSE              FALSE                  FALSE
#>  3:              FALSE              FALSE                  FALSE
#>  4:              FALSE              FALSE                  FALSE
#>  5:              FALSE              FALSE                  FALSE
#>  6:               TRUE               TRUE                   TRUE
#>  7:              FALSE               TRUE                  FALSE
#>  8:               TRUE               TRUE                   TRUE
#>  9:              FALSE              FALSE                  FALSE
#> 10:              FALSE              FALSE                  FALSE
#> 11:              FALSE              FALSE                  FALSE
#> 12:              FALSE              FALSE                  FALSE
#> 13:              FALSE              FALSE                  FALSE
#> 14:              FALSE              FALSE                  FALSE
#> 15:              FALSE              FALSE                  FALSE
#> 16:               TRUE              FALSE                  FALSE
#> 17:              FALSE               TRUE                  FALSE
#> 18:               TRUE               TRUE                   TRUE
#> 19:              FALSE              FALSE                  FALSE
#> 20:              FALSE              FALSE                  FALSE
#> 21:              FALSE              FALSE                  FALSE
#> 22:              FALSE              FALSE                  FALSE
#> 23:               TRUE               TRUE                   TRUE
#>     NUTS_DISTRICT_2021 NUTS_DISTRICT_2027 NUTS_MUNICIPALITY_2021
#>                 <lgcl>             <lgcl>                 <lgcl>
#>     NUTS_PROVINCE_2021 NUTS_PROVINCE_2027 NUTS_REGION_2021 NUTS_REGION_2027
#>                 <lgcl>             <lgcl>           <lgcl>           <lgcl>
#>  1:               TRUE              FALSE             TRUE            FALSE
#>  2:              FALSE              FALSE            FALSE            FALSE
#>  3:              FALSE              FALSE            FALSE            FALSE
#>  4:              FALSE              FALSE            FALSE            FALSE
#>  5:              FALSE              FALSE            FALSE            FALSE
#>  6:               TRUE               TRUE             TRUE             TRUE
#>  7:               TRUE               TRUE             TRUE             TRUE
#>  8:               TRUE               TRUE             TRUE             TRUE
#>  9:              FALSE              FALSE            FALSE            FALSE
#> 10:              FALSE              FALSE            FALSE            FALSE
#> 11:              FALSE              FALSE            FALSE            FALSE
#> 12:              FALSE              FALSE            FALSE            FALSE
#> 13:              FALSE              FALSE            FALSE            FALSE
#> 14:              FALSE              FALSE            FALSE            FALSE
#> 15:              FALSE              FALSE            FALSE            FALSE
#> 16:               TRUE              FALSE             TRUE            FALSE
#> 17:              FALSE               TRUE            FALSE             TRUE
#> 18:               TRUE               TRUE             TRUE             TRUE
#> 19:               TRUE              FALSE             TRUE            FALSE
#> 20:              FALSE               TRUE            FALSE             TRUE
#> 21:              FALSE              FALSE             TRUE            FALSE
#> 22:              FALSE              FALSE            FALSE             TRUE
#> 23:               TRUE               TRUE             TRUE             TRUE
#>     NUTS_PROVINCE_2021 NUTS_PROVINCE_2027 NUTS_REGION_2021 NUTS_REGION_2027
#>                 <lgcl>             <lgcl>           <lgcl>           <lgcl>
#>     POSTAL
#>     <lgcl>
#>  1:  FALSE
#>  2:  FALSE
#>  3:  FALSE
#>  4:  FALSE
#>  5:  FALSE
#>  6:  FALSE
#>  7:  FALSE
#>  8:  FALSE
#>  9:  FALSE
#> 10:  FALSE
#> 11:  FALSE
#> 12:  FALSE
#> 13:  FALSE
#> 14:  FALSE
#> 15:  FALSE
#> 16:  FALSE
#> 17:  FALSE
#> 18:  FALSE
#> 19:  FALSE
#> 20:  FALSE
#> 21:  FALSE
#> 22:  FALSE
#> 23:   TRUE
#>     POSTAL
#>     <lgcl>
  visualize_conversion_matrix(output_file = "conversion_matrix.png")
#> Package 'ggplot2' not installed. Showing text matrix.
#> Key: <from>
#>                             from NBB_DISTRICT_2021 NIS_COUNTRY
#>                           <char>            <lgcl>      <lgcl>
#>  1:            NBB_DISTRICT_2021              TRUE        TRUE
#>  2:                  NIS_COUNTRY             FALSE        TRUE
#>  3:            NIS_DISTRICT_2019             FALSE        TRUE
#>  4:            NIS_DISTRICT_2025             FALSE        TRUE
#>  5:     NIS_DISTRICT_BEFORE_2019             FALSE        TRUE
#>  6:        NIS_MUNICIPALITY_2019              TRUE        TRUE
#>  7:        NIS_MUNICIPALITY_2025              TRUE        TRUE
#>  8: NIS_MUNICIPALITY_BEFORE_2019              TRUE        TRUE
#>  9:            NIS_PROVINCE_2019             FALSE        TRUE
#> 10:            NIS_PROVINCE_2025             FALSE        TRUE
#> 11:     NIS_PROVINCE_BEFORE_2019             FALSE        TRUE
#> 12:              NIS_REGION_2019             FALSE        TRUE
#> 13:              NIS_REGION_2025             FALSE        TRUE
#> 14:       NIS_REGION_BEFORE_2019             FALSE        TRUE
#> 15:                 NUTS_COUNTRY             FALSE       FALSE
#> 16:           NUTS_DISTRICT_2021              TRUE        TRUE
#> 17:           NUTS_DISTRICT_2027             FALSE       FALSE
#> 18:       NUTS_MUNICIPALITY_2021              TRUE        TRUE
#> 19:           NUTS_PROVINCE_2021             FALSE       FALSE
#> 20:           NUTS_PROVINCE_2027             FALSE       FALSE
#> 21:             NUTS_REGION_2021             FALSE       FALSE
#> 22:             NUTS_REGION_2027             FALSE       FALSE
#> 23:                       POSTAL              TRUE        TRUE
#>                             from NBB_DISTRICT_2021 NIS_COUNTRY
#>                           <char>            <lgcl>      <lgcl>
#>     NIS_DISTRICT_2019 NIS_DISTRICT_2025 NIS_DISTRICT_BEFORE_2019
#>                <lgcl>            <lgcl>                   <lgcl>
#>  1:              TRUE             FALSE                    FALSE
#>  2:             FALSE             FALSE                    FALSE
#>  3:              TRUE             FALSE                    FALSE
#>  4:             FALSE              TRUE                    FALSE
#>  5:             FALSE             FALSE                     TRUE
#>  6:              TRUE              TRUE                    FALSE
#>  7:              TRUE              TRUE                    FALSE
#>  8:              TRUE              TRUE                     TRUE
#>  9:             FALSE             FALSE                    FALSE
#> 10:             FALSE             FALSE                    FALSE
#> 11:             FALSE             FALSE                    FALSE
#> 12:             FALSE             FALSE                    FALSE
#> 13:             FALSE             FALSE                    FALSE
#> 14:             FALSE             FALSE                    FALSE
#> 15:             FALSE             FALSE                    FALSE
#> 16:              TRUE             FALSE                    FALSE
#> 17:             FALSE             FALSE                    FALSE
#> 18:              TRUE              TRUE                    FALSE
#> 19:             FALSE             FALSE                    FALSE
#> 20:             FALSE             FALSE                    FALSE
#> 21:             FALSE             FALSE                    FALSE
#> 22:             FALSE             FALSE                    FALSE
#> 23:              TRUE              TRUE                    FALSE
#>     NIS_DISTRICT_2019 NIS_DISTRICT_2025 NIS_DISTRICT_BEFORE_2019
#>                <lgcl>            <lgcl>                   <lgcl>
#>     NIS_MUNICIPALITY_2019 NIS_MUNICIPALITY_2025 NIS_MUNICIPALITY_BEFORE_2019
#>                    <lgcl>                <lgcl>                       <lgcl>
#>  1:                 FALSE                 FALSE                        FALSE
#>  2:                 FALSE                 FALSE                        FALSE
#>  3:                 FALSE                 FALSE                        FALSE
#>  4:                 FALSE                 FALSE                        FALSE
#>  5:                 FALSE                 FALSE                        FALSE
#>  6:                  TRUE                  TRUE                        FALSE
#>  7:                 FALSE                  TRUE                        FALSE
#>  8:                  TRUE                  TRUE                         TRUE
#>  9:                 FALSE                 FALSE                        FALSE
#> 10:                 FALSE                 FALSE                        FALSE
#> 11:                 FALSE                 FALSE                        FALSE
#> 12:                 FALSE                 FALSE                        FALSE
#> 13:                 FALSE                 FALSE                        FALSE
#> 14:                 FALSE                 FALSE                        FALSE
#> 15:                 FALSE                 FALSE                        FALSE
#> 16:                 FALSE                 FALSE                        FALSE
#> 17:                 FALSE                 FALSE                        FALSE
#> 18:                  TRUE                  TRUE                        FALSE
#> 19:                 FALSE                 FALSE                        FALSE
#> 20:                 FALSE                 FALSE                        FALSE
#> 21:                 FALSE                 FALSE                        FALSE
#> 22:                 FALSE                 FALSE                        FALSE
#> 23:                  TRUE                  TRUE                        FALSE
#>     NIS_MUNICIPALITY_2019 NIS_MUNICIPALITY_2025 NIS_MUNICIPALITY_BEFORE_2019
#>                    <lgcl>                <lgcl>                       <lgcl>
#>     NIS_PROVINCE_2019 NIS_PROVINCE_2025 NIS_PROVINCE_BEFORE_2019
#>                <lgcl>            <lgcl>                   <lgcl>
#>  1:              TRUE             FALSE                    FALSE
#>  2:             FALSE             FALSE                    FALSE
#>  3:              TRUE             FALSE                    FALSE
#>  4:             FALSE              TRUE                    FALSE
#>  5:             FALSE             FALSE                     TRUE
#>  6:              TRUE              TRUE                    FALSE
#>  7:              TRUE              TRUE                    FALSE
#>  8:              TRUE              TRUE                     TRUE
#>  9:              TRUE             FALSE                    FALSE
#> 10:             FALSE              TRUE                    FALSE
#> 11:             FALSE             FALSE                     TRUE
#> 12:             FALSE             FALSE                    FALSE
#> 13:             FALSE             FALSE                    FALSE
#> 14:             FALSE             FALSE                    FALSE
#> 15:             FALSE             FALSE                    FALSE
#> 16:              TRUE             FALSE                    FALSE
#> 17:             FALSE             FALSE                    FALSE
#> 18:              TRUE              TRUE                    FALSE
#> 19:             FALSE             FALSE                    FALSE
#> 20:             FALSE             FALSE                    FALSE
#> 21:             FALSE             FALSE                    FALSE
#> 22:             FALSE             FALSE                    FALSE
#> 23:              TRUE              TRUE                    FALSE
#>     NIS_PROVINCE_2019 NIS_PROVINCE_2025 NIS_PROVINCE_BEFORE_2019
#>                <lgcl>            <lgcl>                   <lgcl>
#>     NIS_REGION_2019 NIS_REGION_2025 NIS_REGION_BEFORE_2019 NUTS_COUNTRY
#>              <lgcl>          <lgcl>                 <lgcl>       <lgcl>
#>  1:            TRUE           FALSE                  FALSE         TRUE
#>  2:           FALSE           FALSE                  FALSE        FALSE
#>  3:            TRUE           FALSE                  FALSE        FALSE
#>  4:           FALSE            TRUE                  FALSE        FALSE
#>  5:           FALSE           FALSE                   TRUE        FALSE
#>  6:            TRUE            TRUE                  FALSE         TRUE
#>  7:            TRUE            TRUE                  FALSE         TRUE
#>  8:            TRUE            TRUE                   TRUE         TRUE
#>  9:            TRUE           FALSE                  FALSE        FALSE
#> 10:           FALSE            TRUE                  FALSE        FALSE
#> 11:           FALSE           FALSE                   TRUE        FALSE
#> 12:            TRUE           FALSE                  FALSE        FALSE
#> 13:           FALSE            TRUE                  FALSE        FALSE
#> 14:           FALSE           FALSE                   TRUE        FALSE
#> 15:           FALSE           FALSE                  FALSE         TRUE
#> 16:            TRUE           FALSE                  FALSE         TRUE
#> 17:           FALSE           FALSE                  FALSE         TRUE
#> 18:            TRUE            TRUE                  FALSE         TRUE
#> 19:           FALSE           FALSE                  FALSE         TRUE
#> 20:           FALSE           FALSE                  FALSE         TRUE
#> 21:           FALSE           FALSE                  FALSE         TRUE
#> 22:           FALSE           FALSE                  FALSE         TRUE
#> 23:            TRUE            TRUE                  FALSE         TRUE
#>     NIS_REGION_2019 NIS_REGION_2025 NIS_REGION_BEFORE_2019 NUTS_COUNTRY
#>              <lgcl>          <lgcl>                 <lgcl>       <lgcl>
#>     NUTS_DISTRICT_2021 NUTS_DISTRICT_2027 NUTS_MUNICIPALITY_2021
#>                 <lgcl>             <lgcl>                 <lgcl>
#>  1:               TRUE              FALSE                  FALSE
#>  2:              FALSE              FALSE                  FALSE
#>  3:              FALSE              FALSE                  FALSE
#>  4:              FALSE              FALSE                  FALSE
#>  5:              FALSE              FALSE                  FALSE
#>  6:               TRUE               TRUE                   TRUE
#>  7:              FALSE               TRUE                  FALSE
#>  8:               TRUE               TRUE                   TRUE
#>  9:              FALSE              FALSE                  FALSE
#> 10:              FALSE              FALSE                  FALSE
#> 11:              FALSE              FALSE                  FALSE
#> 12:              FALSE              FALSE                  FALSE
#> 13:              FALSE              FALSE                  FALSE
#> 14:              FALSE              FALSE                  FALSE
#> 15:              FALSE              FALSE                  FALSE
#> 16:               TRUE              FALSE                  FALSE
#> 17:              FALSE               TRUE                  FALSE
#> 18:               TRUE               TRUE                   TRUE
#> 19:              FALSE              FALSE                  FALSE
#> 20:              FALSE              FALSE                  FALSE
#> 21:              FALSE              FALSE                  FALSE
#> 22:              FALSE              FALSE                  FALSE
#> 23:               TRUE               TRUE                   TRUE
#>     NUTS_DISTRICT_2021 NUTS_DISTRICT_2027 NUTS_MUNICIPALITY_2021
#>                 <lgcl>             <lgcl>                 <lgcl>
#>     NUTS_PROVINCE_2021 NUTS_PROVINCE_2027 NUTS_REGION_2021 NUTS_REGION_2027
#>                 <lgcl>             <lgcl>           <lgcl>           <lgcl>
#>  1:               TRUE              FALSE             TRUE            FALSE
#>  2:              FALSE              FALSE            FALSE            FALSE
#>  3:              FALSE              FALSE            FALSE            FALSE
#>  4:              FALSE              FALSE            FALSE            FALSE
#>  5:              FALSE              FALSE            FALSE            FALSE
#>  6:               TRUE               TRUE             TRUE             TRUE
#>  7:               TRUE               TRUE             TRUE             TRUE
#>  8:               TRUE               TRUE             TRUE             TRUE
#>  9:              FALSE              FALSE            FALSE            FALSE
#> 10:              FALSE              FALSE            FALSE            FALSE
#> 11:              FALSE              FALSE            FALSE            FALSE
#> 12:              FALSE              FALSE            FALSE            FALSE
#> 13:              FALSE              FALSE            FALSE            FALSE
#> 14:              FALSE              FALSE            FALSE            FALSE
#> 15:              FALSE              FALSE            FALSE            FALSE
#> 16:               TRUE              FALSE             TRUE            FALSE
#> 17:              FALSE               TRUE            FALSE             TRUE
#> 18:               TRUE               TRUE             TRUE             TRUE
#> 19:               TRUE              FALSE             TRUE            FALSE
#> 20:              FALSE               TRUE            FALSE             TRUE
#> 21:              FALSE              FALSE             TRUE            FALSE
#> 22:              FALSE              FALSE            FALSE             TRUE
#> 23:               TRUE               TRUE             TRUE             TRUE
#>     NUTS_PROVINCE_2021 NUTS_PROVINCE_2027 NUTS_REGION_2021 NUTS_REGION_2027
#>                 <lgcl>             <lgcl>           <lgcl>           <lgcl>
#>     POSTAL
#>     <lgcl>
#>  1:  FALSE
#>  2:  FALSE
#>  3:  FALSE
#>  4:  FALSE
#>  5:  FALSE
#>  6:  FALSE
#>  7:  FALSE
#>  8:  FALSE
#>  9:  FALSE
#> 10:  FALSE
#> 11:  FALSE
#> 12:  FALSE
#> 13:  FALSE
#> 14:  FALSE
#> 15:  FALSE
#> 16:  FALSE
#> 17:  FALSE
#> 18:  FALSE
#> 19:  FALSE
#> 20:  FALSE
#> 21:  FALSE
#> 22:  FALSE
#> 23:   TRUE
#>     POSTAL
#>     <lgcl>
# }
```

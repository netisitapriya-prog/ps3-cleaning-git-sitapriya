clear all
set more off

cd "C:\Users\SitaPriya Amaravadi\Desktop"

capture mkdir "logs"
capture mkdir "processed_data"
log using "logs/ps3.log", replace text

* People dataset

* import as strings
import delimited "data/people_full.csv", clear varnames(1) stringcols(_all)

* clean categorical strings
replace location = strtrim(location)
replace location = strlower(location)
replace location = strproper(location)

replace sex = strtrim(sex)
replace sex = strlower(sex)
replace sex = strproper(sex)

* convert numeric-like strings
foreach v in person_id household_id age height_cm weight_kg systolic_bp diastolic_bp {
    replace `v' = "" if `v' == "NA"
    destring `v', replace
}

* create date/time variables
gen visit_date = date(date_str, "MDY")
format visit_date %td

gen people_year = yofd(visit_date)

gen visit_time = clock(time_str, "hms")
format visit_time %tcHH:MM:SS

misstable summarize
assert !missing(person_id)
isid person_id people_year
bysort person_id: assert _N == 5

* encode categoricals + grouped vars
tab sex, missing
tab location, missing

encode sex, gen(sex_id)
encode location, gen(location_id)

bysort household_id: gen hh_n = _N
bysort household_id (person_id people_year): gen hh_row = _n
bysort household_id: egen hh_mean_age = mean(age)

* export people clean
export delimited using "processed_data/ps3_people_clean.csv", replace

* Households dataset

import delimited "data/households.csv", clear varnames(1) stringcols(_all)

* convert numeric vars
foreach v in household_id year region_id income hh_size {
    replace `v' = "" if `v' == "NA"
    destring `v', replace
}

* encode region
tab region, missing
encode region, gen(region_code)
label list region_code
tab region_code, missing

* grouped summaries
bysort year: egen year_mean_income = mean(income)
bysort region_code year: egen region_year_mean_income = mean(income)

bysort region_code (year): gen region_year_row = _n
bysort region_code: gen region_obs = _N

* regression
reg income i.region_code c.hh_size

* export households clean
export delimited using "processed_data/ps3_households_clean.csv", replace

* Regions panel dataset

import delimited "data/regions.csv", clear varnames(1) stringcols(_all)

* convert numeric vars
foreach v in region_id year median_income population {
    replace `v' = "" if `v' == "NA"
    destring `v', replace
}

* panel QA
drop if missing(region_id) | missing(year)
duplicates report region_id year
isid region_id year

* declare panel
xtset region_id year

* lag variables
gen yoy_change_median_income = median_income - L.median_income
gen median_income_growth_rate = (median_income - L.median_income) / L.median_income

* panel diagnostics
xtdescribe
xtsum median_income population yoy_change_median_income median_income_growth_rate

* export regions clean
export delimited using "processed_data/ps3_regions_clean.csv", replace

* close log
log close
cd "C:\Users\SitaPriya Amaravadi\Desktop\lecture_5_pset"

log using "logs\ps5.log", replace text

import delimited "data\psam_p50.csv", clear varnames(1)

ds
display "Number of variables = " r(k)

describe
display "Number of variables = " r(k)

local numeric_vars AGEP WAGP WKHP SCHL PINCP POVPIP ESR COW MAR SEX RAC1P HISP ADJINC PWGTP
local categorical_vars NAICSP SOCP

display "numeric_vars: `numeric_vars'"
display "categorical_vars: `categorical_vars'"

* Loop over required numeric variables
foreach v of local numeric_vars {

    * Check variable exists
    capture confirm variable `v'

    if _rc == 0 {

        * If not numeric, clean and convert
        capture confirm numeric variable `v'
        if _rc != 0 {
            replace `v' = "" if inlist(strtrim(`v'), "NA", ".", "")
            destring `v', replace
        }
    }
}

local categorical_vars naicsp socp
display "categorical_vars: `categorical_vars'"

* Clean and encode categorical variables
foreach v of local categorical_vars {

    * Standardize string formatting
    replace `v' = strtrim(`v')
    replace `v' = strlower(`v')
    replace `v' = strproper(`v')

    * Encode to numeric ID
    capture drop `v'_id
    encode `v', gen(`v'_id)
}

* Verify new variables exist
describe naicsp_id socp_id


count if missing(serialno)
count if missing(sporder)

duplicates report serialno sporder
isid serialno sporder

* Save cleaned full dataset
save "processed_data\ps5_cleaned_full.dta", replace

* Initialize sample construction table
tempname sample_post
tempfile sample_steps
postfile `sample_post' str80 step int n_remaining int n_excluded using "`sample_steps'", replace

count
local n_prev = r(N)
post `sample_post' ("Start: cleaned observations") (`n_prev') (0)

* Inclusion: ages 25–64
keep if inrange(agep, 25, 64)

count
local n_now = r(N)
post `sample_post' ("Inclusion: age 25–64") (`n_now') (`n_prev' - `n_now')
local n_prev = `n_now'

* Inclusion: WAGP > 0 and WKHP >= 35
keep if wagp > 0 & wkhp >= 35

count
local n_now = r(N)
post `sample_post' ("Inclusion: WAGP > 0 and WKHP >= 35") (`n_now') (`n_prev' - `n_now')
local n_prev = `n_now'

* Inclusion: employed ESR categories (1 or 2)
keep if inlist(esr, 1, 2)

count
local n_now = r(N)
post `sample_post' ("Inclusion: ESR in {1,2} (employed)") (`n_now') (`n_prev' - `n_now')
local n_prev = `n_now'

* Exclusion: drop missing key covariates and categorical IDs
drop if missing(agep, wagp, wkhp, schl, pincp, povpip, esr, cow, mar, sex, rac1p, hisp, adjinc, pwgtp, naicsp_id, socp_id)

count
local n_now = r(N)
post `sample_post' ("Exclusion: drop missing key covariates + IDs") (`n_now') (`n_prev' - `n_now')
local n_prev = `n_now'

* Derived variable: log wage
gen ln_wage = ln(wagp)
label var ln_wage "Log wage (ln of WAGP)"

count
local n_now = r(N)
post `sample_post' ("Derived: ln_wage = ln(WAGP)") (`n_now') (0)

postclose `sample_post'

preserve
use "`sample_steps'", clear
export delimited using "processed_data\ps5_sample_construction.csv", replace
save "processed_data\ps5_sample_construction.dta", replace
restore

* Model macros
local outcome "ln_wage"

local covariates_demo     "c.agep i.sex i.rac1p i.hisp"
local covariates_humancap "c.schl"
local covariates_labor    "c.wkhp i.cow i.mar"
local covariates_occ      "i.naicsp_id i.socp_id"

local model_covariates "`covariates_demo' `covariates_humancap' `covariates_labor' `covariates_occ'"

display "Outcome: `outcome'"
display "Model covariates: `model_covariates'"

* QA summary loop
local qa_vars agep wagp wkhp schl pincp povpip

foreach v of local qa_vars {
    quietly summarize `v'
    display "`v': N=" r(N) " mean=" %9.3f r(mean) " sd=" %9.3f r(sd)
}

* Counts above hour cutoffs
forvalues cutoff = 35/45 {
    quietly count if wkhp >= `cutoff'
    display "Observations with WKHP >= `cutoff': " r(N)
}

* Model 1: demographics only
reg `outcome' `covariates_demo', vce(robust)
est store m1

* Model 2: + human capital
reg `outcome' `covariates_demo' `covariates_humancap', vce(robust)
est store m2

* Model 3: full model
reg `outcome' `model_covariates', vce(robust)
est store m3

* Export regression results table
esttab m1 m2 m3 using "processed_data\ps5_regression_table.rtf", ///
    replace se r2 ar2 label star(* 0.10 ** 0.05 *** 0.01) ///
    title("PS5: Log wage regressions") compress

display "Saved: processed_data\ps5_regression_table.rtf"

ssc install estout, replace

esttab m1 m2 m3 using "processed_data\ps5_regression_table.rtf", ///
    replace se r2 ar2 label star(* 0.10 ** 0.05 *** 0.01) ///
    title("PS5: Log wage regressions") compress
	
	esttab m1 m2 m3 using "processed_data\ps5_regression_table.rtf", replace se r2 ar2 label star(* 0.10 ** 0.05 *** 0.01) title("PS5: Log wage regressions") compress
	
save "processed_data\ps5_analysis_sample.dta", replace

log close

cd "C:\Users\SitaPriya Amaravadi\Desktop\lecture_5_pset"

use "processed_data\ps5_analysis_sample.dta", clear

local keepvars agep wagp wkhp schl pincp povpip esr cow mar sex rac1p hisp adjinc pwgtp ln_wage naicsp_id socp_id

keep `keepvars'

foreach v of local keepvars {
    confirm variable `v'
}

save "processed_data\ps5_analysis_data.dta", replace

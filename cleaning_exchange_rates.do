/**** 

Description: This is a compilation of all the years, cleaning exchange rates, and ranges not caught 

Data:  has been cleaned for each individual ISSP dataset, now compiling to clean the income values, merge in survey dates for missing values, add in exchange rates, and drop countries pre-Euro transition with currency changes. 

Created: 10/10/2023

*/ 


/* Assignment: 
Once you have the cleaned dataset, please create a document that summarizes the following:
- Number of countries in our dataset in each year
- Number of respondents in our dataset in each year
- Fraction of the sample that is female in each year (allowing for an unbalanced sample of
countries across years)
- Average age of the respondent over the entire sample by country
- Average nominal income in each country over the entire sample period
*/

******************* 
* Creates globals for the folders
	global folder = "/Users/--------/Documents/"
	global programs = "${folder}/01_dofiles"
	global raw = "${folder}/02_raw"
	global clean = "${folder}/03_clean"
	global coded = "${folder}/04_crosswalks"
	global results = "${folder}/06_results"
	global temp = "${folder}/07_temp"


************************************************************
* FRED Key 
	set fredkey cc7ca2239c12a7733210e25174258f35, permanently

* Loop through cleaned individual year datasets to drop income values that are missing
	forval i = 1989/2020{
		if `i'!=2001 &`i'!=1999 &`i'!=1997{
		di `i'
		use "${clean}/`i'_data", clear
		drop country
		gen year_survey = `i'
		destring rinc_range, replace
		drop if rinc_range != 0
		// dropping when the income is missing
		drop if rinc < 0 | rinc == 999997 | rinc == 999998 | rinc == 999999 | rinc == 999996 | rinc==9999990 | rinc == 9999999 | rinc == 99999999 | rinc == 99999990 | rinc == 999999998 | rinc == 99999998 | rinc == 9999998 | rinc == 999990 | rinc == 9999997 | rinc == 99999997 | rinc == .
		drop if rinc == .n
		drop if rinc == .a
		// save the first as its own file, append the rest 
		if `i' == 1989 {
			save "${temp}/all_cleaned_years", replace
		}
		if `i' != 1989{
		append using "${temp}/all_cleaned_years"
		save "${temp}/all_cleaned_years", replace 
		}
		}
	}
		
**** cleaning out for other ranges not caught, how many different incomes are reported, drops if less than 20  
		use "${temp}/all_cleaned_years", clear 
		sort c_alphan rinc
		gen x = 1
		collapse (sum) x, by(c_alphan rinc year_survey)
		sort c_alphan year_survey rinc
		gen a = 1 
		collapse (sum) a, by(c_alphan year_survey)
		drop if a < 20
		save "${temp}/c_alphan_years_over_20", replace 
		
		use "${temp}/all_cleaned_years", clear 
		merge m:1 c_alphan year using "${temp}/c_alphan_years_over_20"
		keep if _merge == 3
		drop _merge	
		save "${temp}/all_cleaned_years", replace

********* Cleaning Date

// ** DO NOT RUN THIS PART, hand coding the survey year from ISSP for those without an interview year
// 		use "${temp}/all_cleaned_years", clear 
// 		bysort year_survey c_alphan: gen x = _n 
// 		keep if x == 1
// 		keep c_alphan year_survey
// 		export excel using "${raw}/code_year_survey", firstrow(variables) replace

** after handcoding the years of all the countries 
	import excel using "${coded}/code_year_survey", sheet("Sheet1") firstrow clear
	save "${temp}/cleaning_code_year_survey_dateyr", replace
	* save the ones with interview dates in their own category
	use "${temp}/all_cleaned_years", clear
	preserve 
		drop if dateyr ==. | dateyr == 9999 | dateyr == -9
		save "${temp}/dateyr_not_missing", replace
	restore
	* merge the year of the interview in for those without interview dates
	keep if dateyr ==. | dateyr == 9999 | dateyr == -9
	drop dateyr
	merge m:1 year_survey c_alphan using "${temp}/cleaning_code_year_survey_dateyr"
	keep if _merge == 3
	drop _merge
	* append the two sets 
	append using "${temp}/dateyr_not_missing"
	save "${temp}/all_cleaned_years", replace

	
**** Exchange Rates (OECD and FRED) 
** export to handcode the c_alphan for OECD exchange rates
	import delimited "${raw}/DP_LIVE_26092023221230059.csv", clear 
	rename time dateyr
	keep dateyr location value
	save "${temp}/exchange_rates_OECD", replace
// 	keep if time == 1985
// 	rename time year
// 	rename location country
// 	export excel "${raw}/exchange_rates_codes", firstrow(variables) replace

// turn c_alphan excel into dta file 
	import excel "${coded}/c_alphan_country", sheet("Sheet1") firstrow clear
	save "${coded}/c_alphan_country", replace
** import the exchange rate codes 
	import excel "${coded}/exchange_rates_codes", sheet("Sheet1") firstrow clear
	drop if c_alphan == ""
	rename country location
// merge to get c_alphan
	merge 1:1 c_alphan using "${coded}/c_alphan_country"
// 		preserve 
//			* For the countries not in OECD, pulling exchange data from FRED, handcode the keys
// 			keep if _merge == 2
// 			drop _merge 
// 			export excel using "${coded}/exchange_rate_FRED_codes", firstrow(variables) replace
// 		restore 
	drop _merge
	save "${temp}/OECD_exchange_c_alphan", replace
	
** Create FRED Exchange Rates List (after handcoding the FRED keys)
		import excel "${coded}/exchange_rate_FRED_codes", sheet("Sheet1") firstrow clear 
		save "${coded}/FRED_exchange_rates_codes", replace
		levelsof c_alphan, local(countrylist)
		local a = 1 
		foreach x in `countrylist'{
			use "${coded}/FRED_exchange_rates_codes", clear
			keep if c_alphan == "`x'"
			local key = FRED_code
			import fred `key', clear
			gen dateyr = substr(datestr,1,4)
			destring dateyr, replace
			rename `key' value
			gen c_alphan = "`x'"
			keep c_alphan dateyr value
			if "`x'" == "bd"{
				save "${temp}/FRED_exchange_rates", replace
			}
			else {
				append using "${temp}/FRED_exchange_rates"
				save "${temp}/FRED_exchange_rates", replace
			}
		}

// merge exchange rate codes in
	use "${temp}/OECD_exchange_c_alphan", clear
	merge 1:m c_alphan using "${temp}/all_cleaned_years"
	* Nowary was measured in thousands for three years 
	replace rinc = rinc * 1000 if c_alphan == "no" & year_survey == 2003
	replace rinc = rinc * 1000 if c_alphan == "no" & year_survey == 2005 
	replace rinc = rinc * 1000 if c_alphan == "no" & year_survey == 2007
	drop if _merge == 1
		preserve
			*merge in the FRED exchange rates for those that OECD does not do
			keep if location == ""
			drop _merge
			merge m:1 c_alphan dateyr using "${temp}/FRED_exchange_rates"
			keep if _merge == 3
			gen rinc_US = rinc/value
			save "${clean}/converted_FRED_all_cleaned_years", replace
		restore 
	drop if location == ""
	drop _merge 
// merge exchange rates in
	merge m:1 location dateyr using "${temp}/exchange_rates_OECD"
	drop if _merge == 2
	drop if value == .
	drop _merge
// convert to US dollars 
	gen rinc_US = rinc/value
	sort c_alphan dateyr 
	append using "${clean}/converted_FRED_all_cleaned_years"
	save "${clean}/converted_all_cleaned_years", replace
**** Countries dropped because of Currency changes and no accurate exchange rate dataset
	** Slovenia before 2007, Lithuania before 2013, all of slovakia, bulgaria before 2000 
	use "${clean}/converted_all_cleaned_years", replace 
		drop if c_alphan == "si" & dateyr < 2007
		drop if c_alphan == "lt" & dateyr <2014
		drop if c_alphan == "sk"
		drop if c_alphan == "bg" & dateyr < 1999
		drop if c_alphan == "pl" & dateyr < 1999
		drop if c_alphan == "ru" & dateyr < 1995
		drop if c_alphan == "ee"
		drop if c_alphan == "ve" & dateyr < 2008
		drop if c_alphan == "hr" & dateyr > 2010
	save "${clean}/converted_all_cleaned_years", replace

		

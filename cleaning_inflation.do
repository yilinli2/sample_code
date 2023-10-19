/* 
Date created: 10/18/2023
This file cleans the inflation downdloaded from the World Bank 

*/



** Creates globals for the folders
	global folder = "/Users/yilinli/Documents/Patterson"
	global programs = "$folder/01_dofiles"
	global raw = "$folder/02_raw"
	global clean = "$folder/03_clean"
	global coded = "$folder/04_crosswalks"
	global results = "$folder/06_results"
	global temp = "$folder/07_temp"

// turn c_alphan excel into dta file 
	import excel "$coded/c_alphan_country", sheet("Sheet1") firstrow clear
	save "$coded/c_alphan_country", replace

*********** import dataset 
	import excel "$raw/Inflation-data.xlsx", sheet("hcpi_a") firstrow clear
	local year = 1985
	foreach i of varlist U V W X Y Z AA AB AC AD AE AF AG AH AI AJ AK AL AM AN AO AP AQ AR AS AT AU AV AW AX AY AZ BA BB BC BD BE BF{ 
		rename `i' _`year'
		local year = `year'+1
 	}	
	rename CountryCode inflation_code
	keep _* inflation_code
	reshape long _, i(inflation_code) j(year)
	drop if _ == .
	rename _ h_inflation
	merge m:1 inflation_code using "$coded/c_alphan_country"
	keep if _merge == 3
	drop _merge
	rename year dateyr
	save "$clean/headline_inflation", replace


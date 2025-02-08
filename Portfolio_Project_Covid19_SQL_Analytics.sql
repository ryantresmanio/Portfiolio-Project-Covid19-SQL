--checking if the tables are transfered properly

select * from Covid19..covid_deaths 
order by location, date

select * from Covid19..covid_vaccinations
order by location, date

select * from covid_deaths
where location = 'Philippines' 

select * from Covid19..covid_deaths 
where continent is null
order by location, date
-- this includes continental and global records

select count(*) from Covid19..covid_deaths 
--429435 rows

select Count(*) from Covid19..covid_deaths 
where continent is null
--26525 rows

select Count(*) from Covid19..covid_deaths 
where continent is not null
--402910, will return accurate results






-- Getting the max total case for the Philippines

select  max(total_cases) from covid_deaths
where location = 'Philippines' and continent is not null

-- 4,173,631 but on the csv file, the last entry for total_cases is 4,140,383
-- which means that that value should be the max for that column since it is the accumulated new_cases
-- total_cases must only go up, there's an error since it suddenly went down on 8-20-23



-- Checking for duplicate records

SELECT date, total_cases, COUNT(*)
FROM covid_deaths
WHERE location = 'Philippines'
GROUP BY date, total_cases
HAVING COUNT(*) > 1;





-- Calculating the total_cases

select location, 
	   date, 
	   sum(new_cases) over (partition by location order by date) as tot_cases, 
	   new_cases
from covid_deaths
--where location ='philippines'





-- Looking for other error as the Philippines has and
-- Comparing computed Total Cases (or the max value) vs the actual value on the csv file

with cte_total_cases as(
select location, 
	   date, 
	   total_cases,
	   sum(new_cases) over (partition by location order by date) as tot_cases, 
	   new_cases
from covid_deaths
where continent is not null
)
	select location, 
		   max(tot_cases) as [Real Total Cases], 
		   max(total_cases) as [Total From CSV],
		   max(tot_cases)-max(total_cases) as [Difference]	   
	from cte_total_cases
	group by location
	having max(tot_cases) != max(total_cases)





-- Death Percentage
SELECT 
    location, 
    date, 
    tot_cases, 
    total_deaths, 
    CASE 
        WHEN tot_cases = 0 OR tot_cases IS NULL THEN 0 
        ELSE round((total_deaths / tot_cases * 100),2 )
    END AS DeathPercentage 
FROM #temp_covid_deaths
ORDER BY location, date;

-- Looking for the max cases and deaths for each country
select location, max(tot_cases) as [Total Cases], max(total_deaths) as [Total Deaths]
from #temp_covid_deaths
group by location
order by max(tot_cases) desc

select * from #temp_covid_deaths

-- found that there is also error with total deaths
select location, 
	   date, 
	   new_deaths,
	   total_deaths
from covid_deaths
where new_deaths is null and continent is not null
order by location, date

-- Looks for total_deaths that is not equal to the actual total of deaths
with cte_total_cases as(
select location, 
	   date, 
	   total_deaths,
	   sum(new_deaths) over (partition by location order by date) as tot_det, 
	   new_deaths
from covid_deaths
where continent is not null
)
	select location, 
		   max(tot_det) as [Real Total Cases],
		   max(total_deaths) as [Total From CSV],
		   max(tot_det)-max(total_deaths) as [Difference]	   
	from cte_total_cases
	group by location
	having max(tot_det) != max(total_deaths)


select * from covid_deaths
where continent is null
and new_cases is null  
and total_cases is null
-- on 07-23-23 the total_deaths suddenly drops from 22770 to 22694


-- in that case, i think i should make a temp table or cte with the right number of totals
-- 6, 437 are excluded
-- 39, 364 are included

select count(*) from covid_deaths
where not (continent is null or new_cases is null or total_cases is null);





------ CREATE TEMP TABLE -----


drop table #temp_covid_deaths

Select * 
into #temp_covid_deaths
from covid_deaths
where not (continent is null or new_cases is null or total_cases is null);


--insert new columns
alter table #temp_covid_deaths add tot_cases INT
alter table #temp_covid_deaths add tot_deaths INT

--populate the new columns
update #temp_covid_deaths
set tot_cases = RealValue.tot_cases
from (select
		location, date, 
		sum(new_cases) over (partition by location order by date) as tot_cases
	  from #temp_covid_deaths ) as RealValue
where #temp_covid_deaths.location = RealValue.location
and #temp_covid_deaths.date = RealValue.date

update #temp_covid_deaths
set tot_deaths = RealValue.tot_deaths
from (select
		location, date, 
		sum(new_deaths) over (partition by location order by date) as tot_deaths
	  from #temp_covid_deaths ) as RealValue
where #temp_covid_deaths.location = RealValue.location
and #temp_covid_deaths.date = RealValue.date

 
--  delete  from covid_deaths
-- where location ='north korea'

--delete  from covid_deaths
-- where location ='turkmenistan'


---- END TEMP TABLE ----



select location, date, new_cases, tot_cases, new_deaths, tot_deaths
from #temp_covid_deaths
order by location, date



-- Creating View to do other calculations less complicated

Create view cases_deaths AS
select 
    continent,
    location, 
	population,
    date, 
    total_cases,
    total_deaths,
    new_cases, 
    new_deaths,
    SUM(new_cases) OVER (PARTITION BY location ORDER BY date) AS tot_cases,
    SUM(new_deaths) OVER (PARTITION BY location ORDER BY date) AS tot_deaths
from covid_deaths
where NOT (continent IS NULL OR new_cases IS NULL OR total_cases IS NULL);




-- Showing countries along with the number of population, total cases, and Infection Rate


select location, 
	population, 
	max(tot_cases) as TotalCases, 
	max(tot_cases)*100.0 / cast(population as int) as InfectionRate
from cases_deaths
group by location, population
order by 4 desc

 -- cyprus got the highest with 77% of its population has gotten covid
 -- philippines got 3.6% of its population 
 -- yemen has got the lowest percentage with 0.03%





--percentage of positives who actually died per country

select location, 
	   max(total_deaths) as TotalDeaths, 
	   max(tot_cases) TotalCases,
	   max(total_deaths)*100.0 / max(tot_cases) as DeathPercentage
from cases_deaths
group by location
order by 4 desc




--percentage of total cases comapred population (per day)


select location, date, population,  tot_cases,
tot_cases * 100.0 / cast(population as int) as CaseRate
from cases_deaths
order by location, date







 --Using CTE to get most deaths due to covid19


with ctee as(
select location, 
	   population, 
	   max(tot_cases) as cases, 
	   max(tot_deaths) as deaths 
from cases_deaths
--where date < '2024-04-23' and location = 'cyprus'
group by location, population)

select top 15 
	   location, 
	   population, 
	   sum(deaths) total_deaths, 
	   sum(cases) total_cases 
from ctee
group by location, population
order by total_deaths desc




 -- Using CTE to get least death due to covid19

with ctee as (
  select location, population, 
         max(coalesce(tot_cases, 0)) as cases, 
         max(coalesce(tot_deaths, 0)) as deaths 
  from cases_deaths
  group by location, population
)
select top 15 
  location, population, 
  sum(deaths) as total_deaths, 
  sum(cases) as total_cases 
from ctee
group by location, population
order by total_deaths;






 -- Using CTE to get countries with least total cases

 with ctee as(
select location, population, max(tot_cases) as cases, max(tot_deaths) as deaths from cases_deaths
--where date < '2024-04-23' and location = 'cyprus'
group by location, population)

select top 15 
location, population, sum(deaths) total_deaths, sum(cases) total_cases from ctee
group by location, population
order by total_cases





 -- showing death percentage in Philippines

select location, 
	   date, 
	   population, 
	   tot_cases, tot_cases * 100.0 / cast(population as int) as DeathPercentage
from cases_deaths
where location like '%philip%'
order by date



--ph reached its peak death% on 01-21-24

select location, 
	   date, 
	   population, 
	   tot_cases, tot_cases * 100.0 / cast(population as int) as DeathPercentage
from cases_deaths
where location like '%philip%'
order by 5 desc;



 -- showing what is the value on the csv file for world total deaths


select location, 
	   max(total_deaths) as TotalDeaths
from covid_deaths
where continent is null and location = 'world'
group by location

-- 7,057,132 total deaths in the record





-- calculates total death worldwide


with ct as (
select continent,
	   max(tot_deaths) as TotalDeaths 
from cases_deaths
group by location, continent
)
select continent, sum(TotalDeaths) as TotalDeaths from ct
group by rollup (continent)
order by 
		case
		when continent is null then 1
		else 0
		end,
		TotalDeaths desc

-- 6,990,824 total deaths using this
-- this continental value is more accurate than those in the csv file (calculated below)






-- Gets the total cases, total deaths, and death percentage per continent and overall total


with ct as (
select continent,
	   max(tot_cases) as TotalCases,
	   max(tot_deaths) as TotalDeaths
from cases_deaths
group by location, continent
)
select continent, sum(TotalCases) as TotalCases, sum(TotalDeaths) as TotalDeaths,
sum(TotalDeaths)*100.0 /sum(TotalCases) as DeathPercentage
from ct

group by rollup (continent)
order by 
		case
		when continent is null then 1
		else 0
		end,
		DeathPercentage desc

 -- 775,935,057 cases worldwide







 -- Showing Total vaccinated in the Philippines


with cte_vac as(
select distinct 
	   tcd.continent cont, 
	   tcd.location loc, 
	   tcd.date as da, 
	   tcd.population pop, 
	   cv.new_vaccinations new_vac,
	   sum(cast(cv.new_vaccinations as int)) over (partition by tcd.location order by tcd.date) as TotalVaccinated 
from cases_deaths tcd  
inner join vaccinations cv
on cv.location = tcd.location and cv.date = tcd.date
--where cv.continent = 'europe'
where cv.location = 'philippines'
)
select cont, loc, da, pop, new_vac, TotalVaccinated 
from cte_vac


--max vaccinated in the philippines as of 08-04-24 55,439,750???
--well, this is also the total in the excell




-- Showing the percentage of populatiom who are vaccinated


with cte_vac as(
select distinct 
	   tcd.continent cont, 
	   tcd.location loc, 
	   tcd.date as da, 
	   tcd.population pop, 
	   cv.new_vaccinations new_vac,
	   sum(cast(cv.new_vaccinations as bigint )) over (partition by tcd.location ) as TotalVaccinated
from cases_deaths tcd  
inner join vaccinations cv
on cv.location = tcd.location and cv.date = tcd.date
--where cv.continent = 'europe'
)
select cont, loc, pop, 
TotalVaccinated,
TotalVaccinated*100.0/pop as VaccinationRate
from cte_vac
where TotalVaccinated*100.0/pop > 100
group by loc, cont, pop, TotalVaccinated




-- Showing number of new vaccinated and the rolling total excluding the dates where new_vaccinations have null value

with tot_vac as (
select distinct 
	   tcd.location, 
	   tcd.population,
	   tcd.date,
	   cv.new_vaccinations,
	   sum(cast(cv.new_vaccinations as bigint)) over (partition by tcd.location order by tcd.location, tcd.date) as TotalVaccinated
from cases_deaths tcd 
inner join vaccinations cv
on tcd.location = cv.location and tcd.date = cv.date
)
select location,
	   date,
	   population,
	   new_vaccinations,
	   TotalVaccinated
from tot_vac
where new_vaccinations is not null
order by 1,2






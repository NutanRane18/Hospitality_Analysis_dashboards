create database HOSPITALITY_ANALYSIS;
USE HOSPITALITY_ANALYSIS;
-- IMPORT TABLES USING TABLE DATA IMPORT WIZARD

-- data cleaning
-- dim_date
select * from dim_date;
desc dim_date;
update dim_date set date= str_to_date(date,"%d-%M-%Y");
alter table dim_date 
modify date date, 
rename column `mmm yy` to mmm_yy, 
rename column `week no` to week_no;

update dim_date set day_type = "weekday" where day_type = "weekday";

-- fact_aggreaged_bookings
select * from fact_aggreaged_bookings;
desc fact_aggregated_bookings;
update fact_aggregated_bookings set check_in_date= str_to_date(check_in_date,"%d-%M-%Y");
alter table fact_aggregated_bookings modify check_in_date date;

-- fact_bookings
select * from fact_bookings;
desc fact_bookings;
alter table fact_bookings 
	modify booking_date date, 
	modify check_in_date date, 
	modify check_out_date date;

-- KPI's
-- 1.TOTAL REVENUE
SELECT CONCAT('₹ ',ROUND(SUM(revenue_realized)/1000000, 2), ' M') AS total_revenue
FROM fact_bookings;

-- 2.TOTAL BOOKINGS
SELECT CONCAT(ROUND(COUNT(booking_id)/1000, 0), ' K') AS total_bookings
FROM fact_bookings;

-- 3.TOTAL CAPACITY
SELECT CONCAT(ROUND(SUM(capacity)/1000, 0), ' K') AS total_capacity
FROM fact_aggregated_bookings;

-- 4.OCCUPANCY RATE %
SELECT CONCAT(ROUND((SUM(successful_bookings) / SUM(capacity)) * 100, 2),' %') AS occupancy_rate
FROM fact_aggregated_bookings;

-- 5.TOTAL CANCELLATIONS
SELECT CONCAT(ROUND(COUNT(*)/1000, 0), ' K') AS total_cancellations
FROM fact_bookings
WHERE booking_status = 'Cancelled';

-- 6.CANCELLATION RATE %
SELECT 
    CONCAT(ROUND(
        (SUM(CASE WHEN booking_status = 'Cancelled' THEN 1 ELSE 0 END)
        / COUNT(booking_id)) * 100
    )," %") AS cancellation_rate_per
FROM fact_bookings;

-- 7.ADR
select concat(round((sum(revenue_realized)/count(booking_id))/1000,2)," K") as ADR 
from fact_bookings; 

-- 8.RevPAR
select concat(round(sum(revenue_realized)/(select sum(capacity) from fact_aggregated_bookings)/1000,2)," K") RevPAR 
from fact_bookings;

-- VISUALS
-- 1.REVENUE
-- BY CITY
SELECT h.city, CONCAT(ROUND(SUM(b.revenue_realized)/1000000, 2), "M") AS total_revenue
	FROM fact_bookings b
	JOIN dim_hotels h 
		ON b.property_id = h.property_id
	GROUP BY h.city
	order by total_revenue desc;

-- BY MONTH
select D.mmm_yy month_yr, concat("₹ ",round(sum(B.revenue_realized)/1000000,2)," M") total_revenue 
	from dim_date D
	join fact_bookings B 
		on D.date = B.check_in_date
	group by D.mmm_yy
	order by month_yr desc;

-- BY HOTEL
SELECT h.property_name, CONCAT(ROUND(SUM(b.revenue_realized)/1000000, 2), "M") AS total_revenue
	FROM fact_bookings b
	JOIN dim_hotels h
		ON b.property_id = h.property_id
	GROUP BY h.property_name
	order by sum(b.revenue_realized) desc;

-- BY BOOKING PLATFORM
SELECT booking_platform, CONCAT(ROUND(SUM(revenue_realized)/1000000, 2), "M") AS total_revenue
	FROM fact_bookings
	GROUP BY booking_platform
	order by SUM(revenue_realized) desc;


-- 2.CAPACITY vs SUCCESSFUL BOOKINGS & OCCUPANCY
-- BY CITY
SELECT h.city,
	CONCAT(ROUND(SUM(f.capacity)/1000, 2), ' K') AS total_capacity,
	CONCAT(ROUND(SUM(f.successful_bookings)/1000, 2), ' K') AS successful_bookings,
    CONCAT(ROUND((SUM(f.successful_bookings) / SUM(f.capacity)) * 100, 2),' %') AS occupancy_rate
	FROM fact_aggregated_bookings f
	JOIN dim_hotels h
		ON f.property_id = h.property_id
	GROUP BY h.city;

-- BY HOTEL
SELECT h.property_name,
	CONCAT(ROUND(SUM(f.capacity)/1000, 2), ' K') AS total_capacity,
	CONCAT(ROUND(SUM(f.successful_bookings)/1000, 2), ' K') AS successful_bookings,
    CONCAT(ROUND((SUM(f.successful_bookings) / SUM(f.capacity)) * 100, 2),' %') AS occupancy_rate
	FROM fact_aggregated_bookings f
	JOIN dim_hotels h
		ON f.property_id = h.property_id
	GROUP BY h.property_name;

-- BY CLASS
SELECT r.room_class,
	CONCAT(ROUND(SUM(f.capacity)/1000, 2), ' K') AS total_capacity,
	CONCAT(ROUND(SUM(f.successful_bookings)/1000, 2), ' K') AS successful_bookings,
    CONCAT(ROUND((SUM(f.successful_bookings) / SUM(f.capacity)) * 100, 2),' %') AS occupancy_rate
	FROM fact_aggregated_bookings f
	JOIN dim_rooms r
		ON f.room_category = r.room_id
	GROUP BY r.room_class;


-- 3.WEEKLY TREND (TOTAL REVENUE, BOOKINGS, CANCELLATIONS)
select week_no, 
concat("₹ ",round(sum(revenue_realized)/1000000,2)," M") total_revenue,
concat(round(count(booking_id)/1000,0)," K") total_bookings, 
concat(round(sum(case when B.booking_status = "Cancelled" then 1 end)/1000,0)," K") Total_cancellations
	from dim_date D 
	join fact_bookings B on D.date = B.check_in_date
	group by week_no;


-- 4.WEEKDAY VS WEEKEND ANALYSIS (CITY WISE TOTAL BOOKINGS & REVENUE)
select city, 
concat(round(count(CASE WHEN D.day_type = 'weekday' THEN B.booking_id END)/1000,0)," K") AS weekday_bookings,
concat(round(count(CASE WHEN D.day_type = 'weekend' THEN B.booking_id END)/1000,0)," K") AS weekend_bookings,
concat(round(count(booking_id)/1000)," K") as Total_bookings
	from fact_bookings B
	join dim_date D 
		on B.check_in_date=D.date
	join dim_hotels H 
		on B.property_id=H.property_id
group by H.city;

-- 5.CHECKED OUT, CANCEL, NO SHOW (CITY WISE BOOKING COUNT)
select city,
concat(round(sum(case when booking_status = "Checked Out" then 1 end)/1000,2)," K") Total_checked_out,
concat(round(sum(case when booking_status = "Cancelled" then 1 end)/1000,2)," K") Total_cancelled,
concat(round(sum(case when booking_status = "No Show" then 1 end)/1000,2)," K") Total_no_show,
concat(round(count(booking_id)/1000,0)," K") total_bookings
	from dim_hotels H
	join fact_bookings B on H.property_id=B.property_id
	group by city;

-- 6.AVG RATINGS GIVEN (HOTEL WISE)
SELECT h.property_name,ROUND(AVG(cast(nullif(b.ratings_given,'') as decimal(3,2))), 1) AS avg_rating
	FROM fact_bookings b
	JOIN dim_hotels h
		ON b.property_id = h.property_id
	GROUP BY h.property_name
	order by avg_rating desc;

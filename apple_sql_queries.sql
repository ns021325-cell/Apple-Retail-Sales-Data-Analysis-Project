
--  To view Data --

select * from category;
select * from products;
select * from sales;
select * from stores;
select * from warranty;

-- EXPLORATORY DATA ANALYSIS

select distinct repair_status from warranty;

select distinct store_name from stores;

select distinct category_name from category;

select distinct product_name from products;

select count(*) from sales;

-- IMPROVING QUERY PERFORMANCE

explain Analyze 
select * 
from sales
where product_id ='P-79';

-- Planning Time = 0.079 ms
-- Execution Time = 107.126 ms

-- Now creating index

create index sales_product_id on sales(product_id);

explain analyze 
select * 
from sales
where product_id ='P-79';

--After creation of indexes query performances are increased to
--"Planning Time = 0.503 ms
--"Execution Time = 10.101  ms

create index sales_store_id on sales(store_id);

create index sales_quantity on sales(quantity);

create index sale_date on sales(sale_date);

create index sales_product_id_store_id on sales(product_id, store_id);

-- BUSINESS PROBLEMS

-- 1.Find the number of stores in each country.

select * from stores; --To get clear understanding about table before solving the question.

select 
country,
count(store_id) as Total_Stores
from stores
group by country
order by count(store_id) desc;


--  2.Calculate the total number of units sold by each store.

select
    s.store_id,
    st.store_name,
    sum(s.quantity) as total_unit_sold
from sales as s
join
stores as st
on st.store_id = s.store_id
group by 1, 2
order by 3 desc;


-- 3.Identify how many sales occurred in December 2023.

select 
    count(*) as total_sales
from sales
where to_char(sale_date, 'MM-YYYY') = '12-2023';


-- 4.Determine how many stores have never had a warranty claim filed.

select count(*) from stores
where store_id not in (
                       select distinct store_id
					   from sales as s 
					   right join warranty as w on s.sale_id = w.sale_id
                      );

					  
-- 5.Calcutate the percentage of warranty claims marked as "Rejected" .

select 
    ROUND(
          count(claim_id)/
		                 (select count(*) from warranty)::numeric
		  * 100,
	  2) as rejected_percentage
from warranty
where repair_status = 'Rejected';


-- 6.Identify top 5 store had the highest total units sold in 2024.

select 
     s.store_id,
     st.store_name,
     sum(s.quantity)
from sales as s
join stores as st
on s.store_id = st.store_id
where to_char(sale_date,'YYYY')='2024'
group by 1, 2
order by 3 desc
limit 5;


-- 7.Count the number of unique products sold in 2023.

select
    count(distinct product_id)
from sales
where to_char(sale_date,'YYYY')='2023';


-- 8.Find the average price of products in each category.

select
    p.category_id,
    c.category_name,
    ROUND(Avg(p.price)::numeric, 2) as Avg_price
from products as p
join 
category as c
on p.category_id = c.category_id
group by 1, 2 
order by 3 desc;


-- 9.How many warranty claims were filed in 2024?

select
    count(*) 
from warranty
where extract(year from claim_date)=2024;


-- 10.For each store, identify the best-selling day based on highest quantity sold.

select * 
from
    (
	 select
         store_id,
         to_char(sale_date, 'day') as day_name,
         sum(quantity) as Total_Quantity_sold,
         rank() over(partition by store_id order by sum(quantity) desc) as rank
     from sales
     group by 1,2
    ) as tb1
where rank = 1;


-- 11.Identify the least selling product in each country for each year based on total units sold.
select extract(year from sale_date)from sales
group by 1;



with product_rank
as
(
select 
     st.country,
	 p.product_name,
	 sum(s.quantity) as total_qty_sold,
	 extract(year from s.sale_date) as yearwise,
	 rank() over(partition by st.country,extract(year from s.sale_date) order by sum(s.quantity)) as rank
from sales as s
join
stores as st
on s.store_id=st.store_id
join 
products as p
on s.product_id=p.product_id
group by 1,2,4
)
select *
from product_rank
where rank=1;

-- 12.Calculate how many warranty claims were filed within 180 days of product sale.

select
    count(*)
from warranty as w
left join
sales as s
on s.sale_id=w.sale_id
where 
w.claim_date-s.sale_date<=180;

-- 13.Determine how many warranty claims were filed for products launched in the last two years.

select
     p.product_name,
	 count(claim_id) as no_of_claims,
	 count(s.sale_id) as no_of_sales
from warranty as w
right join
sales as s
on s.sale_id=w.sale_id
join
products  as p
on p.product_id=s.product_id
where p.launch_date>=current_date - interval '2 years'
group by 1
having count(claim_id)>0;


-- 14.List the months in the last three years where sales exceeded 5000 units in the  USA.

select
     to_char(sale_date,'MM,YYYY') AS month,
	 sum(s.quantity) as total_units_sold
from sales as s
join
stores as st
on s.store_id=st.store_id
where
     st.country='United States'
	 and
	 s.sale_date>=current_date - interval '3 years'
group by 1
having sum(s.quantity)>=5000;


-- 15.Identify the product category with the most warranty claims filed in the last two years.

select
     c.category_name,
	 count(w.claim_id) as total_claims
from warranty as w
left join
sales as  s
on w.sale_id=s.sale_id
join 
products as p
on p.product_id=s.product_id
join
category as c
on c.category_id=p.category_id
where 
    w.claim_date>=current_date - interval'2year'
group by 1
order by count(w.claim_id) desc;


-- 16.Determine the  percentage chance of receiving warranty claims after each purchase for each country.

select
     country,
	 total_units_sold,
	 total_claim,
	 round(coalesce(total_claim::numeric/total_units_sold::numeric * 100 , 0) , 2) as risk
from
(select
      st.country,
	  sum(quantity) as total_units_sold,
	  count(w.claim_id) as  total_claim
from sales as s
join stores as st
on s.store_id=st.store_id
left join
warranty as  w
on w.sale_id=s.sale_id
group by 1) t1
order by 4 desc;


-- 17.Analyze the year-on-year growth ratio for each store.

with yearly_sales
as
(
  select
      S.store_id,
      st.store_name,
      extract(year from sale_date) as Year_of_sale,
      sum(p.price * s.quantity) as total_sale
  from sales as s
  join 
  products as p
  on 
  s.product_id = p.product_id
  join 
  stores as st
  on 
  st.store_id = s.store_id
  group by 1, 2, 3
  order by 1, 2, 3
),

growth_ratio
as
(
select
     store_name,
     year_of_sale,
     lag(total_sale, 1) over(partition by store_name order by year_of_sale) as last_year_sale,
     total_sale as current_year_sale
from yearly_sales
)

select
    store_name,
    year_of_sale,
    last_year_sale,
    current_year_sale,
    round((current_year_sale - last_year_sale)::numeric/last_year_sale::numeric * 100,2) as growth_ratio_YOY
from growth_ratio
where 
     last_year_sale is not null
     and 
     year_of_sale<>2024;


-- 18.Calculate the correlation between product price and warranty claims for products sold in the tast five years, segmented by price range.

select 
case
when p.price < 500  then 'lower cost'
when p.price between 500 and 1000 then 'moderate cost'
else 'High cost'
end as price_segment,
count(w.claim_id) as total_claim
from warranty as w
left join sales as s
on s.sale_id = w.sale_id
join products as p
on p.product_id = s.product_id
where claim_date >= current_date - interval '5years'
group by 1
order by 2 desc;


--19.Identify the store with the highest percentage of "Completed" claims relative to total claims filed

with completed
as
(select
s.store_id,
count(w.claim_id) as completed
from sales as s
right join warranty as w
on s.sale_id = w.sale_id
where w.repair_status = 'Completed'
group by 1), 

total_repaired 
as
(select
s.store_id,
count(w.claim_id) as total_repaired
from sales as s
right join warranty as w
on s.sale_id = w.sale_id
group by 1)

select 
tr.store_id,
tr.total_repaired,
c.completed,
ROUND(c.completed::numeric/tr.total_repaired::numeric * 100, 2) as percentage_of_completed
from completed as c
join total_repaired as tr
on c.store_id = tr.store_id
order by 4 desc

--20.Write a query to calculate the monthly running total of sales for each store over the past four years and compare trends during this period.

with monthly_sales
as
(select
store_id,
extract(year from sale_date) as year,
extract(month from sale_date) as month,
sum(p.price * s.quantity) as Total_profit
from sales as s
join products as p
on s.product_id = p.product_id
group by 1, 2, 3
order by 1, 2, 3)

select
store_id, 
year, 
month, 
Total_profit, 
sum(total_profit) over(partition by store_id order by year, month) as Running_total
from monthly_sales;














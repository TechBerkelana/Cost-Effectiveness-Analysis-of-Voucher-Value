/*dampak terhadap jumlah customer*/

WITH TC AS 
( 
SELECT count( distinct customer_id) total_customer    
FROM `bitlabs-dab.I_CID_03.order` 
WHERE voucher_name = "mass_voucher_50%"   
)

SELECT
    total_customer as customer50,
    count( distinct customer_id) as customer25
FROM 
    tc,`bitlabs-dab.I_CID_03.order` 
WHERE 
    voucher_name = "mass_voucher_25%" 
GROUP BY 1; 
--2839 :  345 customers  
--------------------------------------------------------------------------------------------------------------------------
SELECT count( distinct customer_id) total_customer    
FROM `bitlabs-dab.I_CID_03.order` 
WHERE voucher_name = "mass_voucher_50%" AND voucher_value != 0.0  ;  --2835 total customer (99.8% customers use 50% voucher in month 3)

SELECT count( distinct customer_id) total_customer    
FROM `bitlabs-dab.I_CID_03.order` 
WHERE voucher_name = "mass_voucher_25%" AND voucher_value != 0.0 ; -- 345 total customer (100% customers use 25% voucher in month 6)
---------------------------------------------------------------------------------------------------------------------------

/*apakah ada dampak terhadap total spend rata rata customer jika diberi 50 atau 25 % welcome voucher?*/
WITH V50 as 
(
SELECT avg(Total_value) avg50    
FROM `bitlabs-dab.I_CID_03.order` 
WHERE voucher_name = "mass_voucher_50%" )

SELECT
    ROUND (V50.avg50,2) AS avg50,
    ROUND(avg(Total_value),2) as avg25
FROM 
    V50,`bitlabs-dab.I_CID_03.order`
where 
    voucher_name = "mass_voucher_25%" 
group by 1; 
---in a month, the average customer spend more 0.01 SGD when welcome discount voucher change from 50% to 25%
---------------------------------------------------------------------------------------------------------------------------------

/*Bagaimana dampak terhadap transaksi dalam satu bulanya?*/

WITH V50 AS (

SELECT 
  count(transaction_id) Total_Transaction_50_voucher     
FROM `bitlabs-dab.I_CID_03.order` 
WHERE voucher_name = "mass_voucher_50%" and  voucher_value !=0),

comparedata as (
SELECT 
  count(transaction_id) Total_Transaction_25_voucher,
  Total_Transaction_50_voucher   
FROM 
  `bitlabs-dab.I_CID_03.order`,V50 
WHERE 
    voucher_name = "mass_voucher_25%" and  voucher_value !=0
GROUP by 2)

SELECT 
    100*ROUND((Total_Transaction_25_voucher-Total_Transaction_50_voucher)/Total_Transaction_50_voucher,3) AS Percent_decrease
FROM comparedata; 
---in june, when customer got 25% welcome voucher, transaction drop 86.8%  compared to transaction with 50% welcome voucher in march


---------------------------------------------------------------------------------------------------------------------------------------------------

/*bagaimana dengan kondisi revenue yang didapatkan berbanding spend yang dikeluarkan untuk generate voucher kepada konsumen?*/

SELECT  CONCAT("$",ROUND(SUM(total_value + tax_value),2)) AS Revenue_SGD,concat("$",cast(SUM(voucher_value) AS INT)) AS Company_spend_voucher
FROM `bitlabs-dab.I_CID_03.order`
WHERE voucher_name = 'mass_voucher_50%';
---$40434.31  Total Revenue generated by a company and the company spend $18536 (SGD) for generating  mass_voucher_50%

 SELECT  CONCAT("$",ROUND(SUM(total_value + tax_value),2)) AS Revenue_SGD,concat("$",cast(SUM(voucher_value) AS INT)) AS Company_spend_voucher
FROM `bitlabs-dab.I_CID_03.order`
WHERE voucher_name = 'mass_voucher_25%';

----$5341.33 Total Revenue generated by a company and the company spend $1529 (SGD) for generating  mass_voucher_25%


----------------------------------------------------------------------------------------------------------------------------------------------------


/*Bagaimana keadaan rata rata transaksi mingguanya ? dan berapa transaksi tertinggi yang terjadi dalam satu minggu? dan berapa yang terendah?*/

WITH WV50 AS 
(
SELECT 
          distinct    
          count(transaction_id) over(partition by transaction_date) total_transaction,
          transaction_date,
          extract(day FROM transaction_date) day,
          voucher_name voucher
          
FROM `bitlabs-dab.I_CID_03.order` 
WHERE 
     voucher_value !=0 and voucher_name = "mass_voucher_50%" 
order by 1 desc
),

WG as 
(
    SELECT
     *,
     case 
          WHEN day <=5  THEN 'WEEK 1'
          WHEN day <=12 THEN 'WEEK 2'
          WHEN day <=19 THEN 'WEEK 3'
          WHEN day <=26 THEN 'WEEK 4'
          WHEN day <=31 THEN 'WEEK 5' END AS WEEK_GROUP_MARCH
    FROM WV50
)
SELECT  
distinct WG.week_group_march,
SUM(WG.total_transaction) over(partition by WG.week_group_march)as Total_Weekly_transaction_MARCH,
FROM WG 
order by 1 ; 
--weekly average transaction was 926.8 with the most busy week reach 1175 transaction on week 3 and the quietest week was on week 5 with 683 transaction if customer got 50% welcome voucher 

WITH WV25 AS 
(
    SELECT    
            distinct    
              count(transaction_id) over(partition by transaction_date) total_transaction,
               transaction_date,
               extract(day FROM transaction_date) day,
               voucher_name voucher

    FROM `bitlabs-dab.I_CID_03.order` 
    WHERE 
              voucher_value !=0  and voucher_name = "mass_voucher_25%" 
    order by 1 desc
),

WGJ as 
(
    SELECT
      *,
      case 
            WHEN day <=4 THEN 'WEEK 1'
            WHEN day<=11 THEN 'WEEK 2'
            WHEN day <=18 THEN 'WEEK 3'
            WHEN day <=25 THEN 'WEEK 4'
            WHEN day <=30 THEN 'WEEK 5'
            END AS WEEK_GROUP_JUNE
    FROM WV25
)


    SELECT  
      distinct wgj.week_group_june,
      SUM(wgj.total_transaction) over(partition by wgj.week_group_june)as Total_Weekly_transaction_JUNE,
      FROM wgj
    order by 1 ;
 --weekly average transaction was just 122 : 927 (transaction when 50% voucher delivered)  with max transaction just reach 194 transaction on week 4 and the quietest week was on week 1 with just 48 transaction

---------------------------------------------------------------------------------------------------------------------------------

----Recency-Frequency-Monetary (RFM) analysis 
--SOURCE : http://www.silota.com/docs/recipes sql-recency-frequency-monetary-rfm-customer-analysis.html

#uses past purchase behavior to segment customers.
# with this technique potentially we could : 
--identify our most loyal customers by segmenting one-time buyers from customers with repeat purchases
--increase customer retention and lifetime value
---increase average order size
---- can be consideration to control the % of discount that will give to the customer 

#using this  as base score for grouping customer e.g high value,repeat, at-risk,onetime,lost or use another way, it depends on business user decision

WITH GROUPDATA as (
  #voucher50
SELECT 
    customer_id id,
    transaction_date date,
    transaction_id,
    Total_value,
    voucher_name
FROM 
    `bitlabs-dab.I_CID_03.order`
WHERE voucher_name = "mass_voucher_50%"  AND voucher_value !=0),

RFMIndices1 AS (
SELECT
    id,
    max(date) Last_order_date,
    count(*) as count_order,
    round(avg(Total_value),2) as avg_purchase,
    voucher_name
FROM 
    groupdata
GROUP BY 1,5),

RFMIndices2 AS (
SELECT
       id,
       ntile(4) over (order by last_order_date) as rfm_recency,
       ntile(4) over (order by count_order) as rfm_frequency,
       ntile(4) over (order by avg_purchase) as rfm_monetary,
       voucher_name
FROM
    RFMIndices1)
select id, 
      rfm_recency*100 + rfm_frequency*10 + rfm_monetary as rfm_combined,
      voucher_name
FROM 
RFMIndices2 ;


--------------------
WITH GROUPDATA as (
  #voucher25
SELECT 
    customer_id id,
    transaction_date date,
    transaction_id,
    Total_value,
    voucher_name
FROM 
    `bitlabs-dab.I_CID_03.order`
WHERE voucher_name = "mass_voucher_25%"  AND voucher_value !=0
),

RFMIndices1 AS 
(
SELECT
    id,
    max(date) Last_order_date,
    count(*) as count_order,
    round(avg(Total_value),2) as avg_purchase,
    voucher_name
FROM 
    groupdata
GROUP BY 1,5),

RFMIndices2 AS (
SELECT
    id,
       ntile(4) over (order by last_order_date) as rfm_recency,
       ntile(4) over (order by count_order) as rfm_frequency,
       ntile(4) over (order by avg_purchase) as rfm_monetary,
       voucher_name
FROM
    RFMIndices1)

select id, 
rfm_recency*100 + rfm_frequency*10 + rfm_monetary as rfm_combined,
voucher_name
FROM 
RFMIndices2 





 

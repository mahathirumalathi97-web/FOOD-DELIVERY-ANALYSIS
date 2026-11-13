create database food_delivery;
use food_delivery;
SHOW TABLES;

--  view the table rows
SELECT COUNT(*) AS total_customers FROM customers;
SELECT COUNT(*) AS total_restaurants FROM restaurants;
SELECT COUNT(*) AS total_orders FROM cleaned_orders;
SELECT COUNT(*) AS total_deliveries FROM cleaned_delivery;
SELECT COUNT(*) AS total_master_food_delivery FROM master_food_delivery;

SHOW DATABASES;
SHOW TABLES;

-- Extra SQL Query A: Overall Business KPIs (Revenue, AOV, Cancellation Rate)
SELECT 
    COUNT(order_id) AS total_orders,
    SUM(CASE WHEN order_status = 'Delivered' THEN 1 ELSE 0 END) AS delivered_orders,
    SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
    ROUND(SUM(CASE WHEN order_status = 'Delivered' THEN order_value ELSE 0 END), 2) AS total_revenue,
    ROUND(AVG(CASE WHEN order_status = 'Delivered' THEN order_value END), 2) AS avg_order_value_aov,
    ROUND((SUM(CASE WHEN order_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0) / COUNT(order_id), 2) AS cancellation_rate_pct
FROM cleaned_orders;

-- Extra SQL Query B: Customer Retention & Repeat Rate (CTE use panni)
WITH CustomerOrderCounts AS (
    SELECT 
        customer_id,
        COUNT(order_id) AS order_count
    FROM cleaned_orders
    WHERE order_status = 'Delivered'
    GROUP BY customer_id
)
SELECT 
    COUNT(customer_id) AS total_active_customers,
    SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND((SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) * 100.0) / COUNT(customer_id), 2) AS customer_retention_rate_pct
FROM CustomerOrderCounts;


-- Q1.What are the peak order hours and days of the week? 
-- A. peak order hours
SELECT 
    order_hour,
    COUNT(order_id) AS total_orders,
    ROUND(SUM(CASE WHEN order_status = 'Delivered' THEN order_value ELSE 0 END), 2) AS total_revenue
FROM cleaned_orders
GROUP BY order_hour
ORDER BY total_orders DESC;

-- B. Peak Days of the Week
SELECT 
    order_day,
    COUNT(order_id) AS total_orders,
    ROUND(SUM(CASE WHEN order_status = 'Delivered' THEN order_value ELSE 0 END), 2) AS total_revenue
FROM cleaned_orders
GROUP BY order_day
ORDER BY total_orders DESC;

 -- -- Q2. Which restaurants and cuisines generate the highest revenue?
-- A. Top 5 Revenue Generating Restaurants
SELECT 
    r.restaurant_id,
    r.name AS restaurant_name,
    r.cuisine_type,
    COUNT(o.order_id) AS total_delivered_orders,
    ROUND(SUM(o.order_value), 2) AS total_revenue
FROM cleaned_orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
WHERE o.order_status = 'Delivered'
GROUP BY r.restaurant_id, r.name, r.cuisine_type
ORDER BY total_revenue DESC
LIMIT 5;

-- B. Revenue by Cuisine Type
SELECT 
    r.cuisine_type,
    COUNT(o.order_id) AS total_delivered_orders,
    ROUND(SUM(o.order_value), 2) AS total_revenue,
    ROUND(AVG(o.order_value), 2) AS avg_order_value
FROM cleaned_orders o
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
WHERE o.order_status = 'Delivered'
GROUP BY r.cuisine_type
ORDER BY total_revenue DESC;

-- Q3. What is the average delivery time, and how does it impact ratings?
-- A. Overall Average Delivery Time & Delay Rate
SELECT 
    ROUND(AVG(delivery_time_mins), 2) AS avg_delivery_time_mins,
    ROUND(AVG(distance_km), 2) AS avg_distance_km,
    SUM(CASE WHEN is_delayed = 'Yes' THEN 1 ELSE 0 END) AS delayed_orders,
    ROUND((SUM(CASE WHEN is_delayed = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(order_id), 2) AS delay_rate_pct
FROM cleaned_delivery;

-- B. Delivery Time vs. Restaurant Rating (Since order-level ratings aren't in dataset)
SELECT 
    r.rating AS restaurant_rating,
    COUNT(d.order_id) AS total_deliveries,
    ROUND(AVG(d.delivery_time_mins), 2) AS avg_delivery_time_mins,
    ROUND((SUM(CASE WHEN d.is_delayed = 'Yes' THEN 1 ELSE 0 END) * 100.0) / COUNT(d.order_id), 2) AS delay_rate_pct
FROM cleaned_orders o
JOIN cleaned_delivery d ON o.order_id = d.order_id
JOIN restaurants r ON o.restaurant_id = r.restaurant_id
WHERE o.order_status = 'Delivered'
GROUP BY r.rating
ORDER BY r.rating DESC;

-- Q4. Which cities/regions have the highest order cancellation rates?
SELECT 
    c.city AS customer_city,
    COUNT(o.order_id) AS total_orders,
    SUM(CASE WHEN o.order_status = 'Delivered' THEN 1 ELSE 0 END) AS delivered_orders,
    SUM(CASE WHEN o.order_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_orders,
    ROUND((SUM(CASE WHEN o.order_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0) / COUNT(o.order_id), 2) AS cancellation_rate_pct
FROM cleaned_orders o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.city
ORDER BY cancellation_rate_pct DESC;

-- Q5. Who are the top 10% high-value repeat customers?
WITH RepeatCustomerSpend AS (
    SELECT 
        c.customer_id,
        c.name AS customer_name,
        c.city,
        COUNT(o.order_id) AS total_orders,
        ROUND(SUM(o.order_value), 2) AS total_spent
    FROM cleaned_orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'Delivered'
    GROUP BY c.customer_id, c.name, c.city
    HAVING COUNT(o.order_id) > 1
),
RankedCustomers AS (
    SELECT 
        *,
        NTILE(10) OVER (ORDER BY total_spent DESC) AS spend_decile
    FROM RepeatCustomerSpend
)
SELECT 
    customer_id,
    customer_name,
    city,
    total_orders,
    total_spent
FROM RankedCustomers
WHERE spend_decile = 1
ORDER BY total_spent DESC;

-- Q6. What is the month-over-month (MoM) revenue growth trend?
WITH MonthlyRevenue AS (
    SELECT 
        order_month,
        COUNT(order_id) AS total_delivered_orders,
        ROUND(SUM(order_value), 2) AS current_month_revenue
    FROM cleaned_orders
    WHERE order_status = 'Delivered'
    GROUP BY order_month
)
SELECT 
    order_month,
    total_delivered_orders,
    current_month_revenue,
    LAG(current_month_revenue) OVER (ORDER BY order_month) AS previous_month_revenue,
    ROUND(
        ((current_month_revenue - LAG(current_month_revenue) OVER (ORDER BY order_month)) * 100.0) / 
        LAG(current_month_revenue) OVER (ORDER BY order_month), 
    2) AS mom_growth_pct
FROM MonthlyRevenue
ORDER BY order_month;
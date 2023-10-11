/*
========== Welcome to my SQL project! ==========

In this project, I will be querying various aspects of 
a music store dataset (source: DBeaver Sample Database). 
I'll divide this project into 4 main parts:
	1. Customer Data
	2. Music Trends
	3. Profit Analysis
	4. Employee Insights
I hope you find this project engaging and insightful. 

======= Thank you for checking it out! :) =======
*/



/* 1. Customer Data */


-- Question: Find the customer who made the largest single purchase (by invoice total).

SELECT 
	c.FirstName || ' ' || c.LastName AS CustomerName, 
	COUNT(i.InvoiceId) AS TotalPurchase
FROM Customer AS c
INNER JOIN Invoice AS i ON c.CustomerId = i.CustomerId
GROUP BY CustomerName
HAVING TotalPurchase = (SELECT 
							COUNT(InvoiceId) AS MaxPurchase
						FROM Invoice
						GROUP BY CustomerId
						ORDER BY 1 DESC
						LIMIT 1)
ORDER BY CustomerName ASC;

-- Comment: Many customers have made purchases in the maximum amount (7).


-- Question: Have any customers purchased in different years?

SELECT 
	CustomerName, COUNT(PurchaseYear) AS TotalPurchaseInDiffYear 
FROM (SELECT 
	  	DISTINCT(c.FirstName || ' ' || c.LastName) AS CustomerName,
	  	STRFTIME('%Y', i.InvoiceDate) AS PurchaseYear
	  FROM Customer AS c
	  INNER JOIN Invoice AS i ON c.CustomerId = i.CustomerId
	  ORDER BY 1 ASC) AS NewTable
GROUP BY 1
HAVING TotalPurchaseInDiffYear != 1;

-- Comment: All of the customers have purchased in different years.


-- Question: Have any customers purchased in 2 different months in a row?

WITH NewTable AS (
	SELECT 
		DISTINCT(c.FirstName || ' ' || c.LastName) AS CustomerName,
		STRFTIME('%Y', i.InvoiceDate) AS PurchaseYear,
		STRFTIME('%m', i.InvoiceDate) AS PurchaseMonth
	FROM Customer AS c
	INNER JOIN Invoice AS i ON c.CustomerId = i.CustomerId
	ORDER BY 1 ASC
)

SELECT 
	COUNT(DISTINCT(CustomerName)) AS TotalCustomer
FROM (SELECT 
	  	DISTINCT(nt1.CustomerName), 
	  	nt1.PurchaseYear, 
	  	nt1.PurchaseMonth, 
	  	nt2.PurchaseMonth
	  FROM NewTable AS nt1
	  INNER JOIN NewTable AS nt2 ON nt1.CustomerName = nt2.CustomerName AND nt1.PurchaseYear = nt2.PurchaseYear
	  WHERE nt1.PurchaseMonth - nt2.PurchaseMonth = 1) AS NewTable2;

-- Comment: Only 40 customers who have purchased in 2 different months in a row.

	 
-- Question: Find customers who didn't make a purchase in 2007.

SELECT c.CustomerId AS TotalCustomer
FROM Customer AS c
EXCEPT
SELECT DISTINCT(c.CustomerId)
FROM Customer AS c
INNER JOIN Invoice AS i ON c.CustomerId = i.CustomerId 
WHERE CAST(STRFTIME('%Y', i.InvoiceDate) AS INTEGER) IN (2007)
ORDER BY 1 ASC;

-- Comment: There were 13 customers who didn't make a purchase in 2007.
	 


/* 2. Music Trends */


-- Question: Find the best-selling genre in each country.

WITH NewTable AS (
	SELECT 
		c.Country, 
		g.name AS PopularGenre, 
		COUNT(il.Quantity) AS TotalGenreSales,
		SUM(COUNT(il.Quantity)) OVER(PARTITION BY Country) AS TotalSales,
		DENSE_RANK() OVER(PARTITION BY c.Country ORDER BY COUNT(il.Quantity) DESC) AS Ranking
	FROM Customer AS c
	INNER JOIN Invoice AS i ON c.CustomerId = i.CustomerId 
	INNER JOIN InvoiceLine AS il ON i.InvoiceId  = il.InvoiceId 
	INNER JOIN Track AS t ON il.TrackId  = t.TrackId
	INNER JOIN Genre AS g ON t.GenreId  = g.GenreId
	GROUP BY 1, 2
	ORDER BY 1, 4
)

SELECT 
	Country, 
	PopularGenre AS BestSellingGenre, 
	ROUND((100.0 * TotalGenreSales) / TotalSales, 2) || '%' AS PercentSales
FROM NewTable
WHERE Ranking = 1;

-- Comment: The majority of countries' best sellers were the rock genre.


-- Question: What was the most popular genre in each year?

WITH YearlyGenreRank AS (
    SELECT
        STRFTIME('%Y', i.InvoiceDate) AS PurchaseYear,
        g.Name AS Genre,
        SUM(il.Quantity) AS TotalSales,
        RANK() OVER (PARTITION BY STRFTIME('%Y', i.InvoiceDate) ORDER BY SUM(il.Quantity) DESC) AS GenreRank
    FROM Invoice AS i
    INNER JOIN InvoiceLine AS il ON i.InvoiceId = il.InvoiceId
    INNER JOIN Track AS t ON il.TrackId = t.TrackId 
    INNER JOIN Genre AS g ON t.GenreId = g.GenreId
    GROUP BY 1, Genre
)

SELECT 
	PurchaseYear, 
	Genre
FROM YearlyGenreRank
WHERE GenreRank = 1
ORDER BY PurchaseYear;

-- Comment: Every year it was always dominated by the rock genre.


-- Question: What about the increases of sales of the rock genre every year (in %)?

--Solution 1:
WITH NewTable AS (
	SELECT 
		STRFTIME('%Y', i.InvoiceDate) AS PurchaseYear, 
		SUM(il.Quantity) AS TotalSales
	FROM Invoice AS i
	INNER JOIN InvoiceLine AS il ON i.InvoiceId = il.InvoiceId
	INNER JOIN Track AS t ON il.TrackId = t.TrackId 
	INNER JOIN Genre AS g ON t.GenreId = g.GenreId
	WHERE LOWER(g.Name) == 'rock' -- or UPPER(g.Name) == 'ROCK'
	GROUP BY 1
)

SELECT 
	nt2.PurchaseYear AS Year, 
	nt1.TotalSales AS PreviousYearSales, 
	nt2.TotalSales AS CurrentYearSales, 
	ROUND((nt2.TotalSales - nt1.TotalSales) * 100.0 / nt1.TotalSales, 2) || '%' AS PercentIncrease
FROM NewTable AS nt1,  NewTable AS nt2 -- FROM NewTable AS nt1 INNER JOIN NewTable AS nt2 ON nt2.PurchaseYear - nt1.PurchaseYear = 1
WHERE nt2.PurchaseYear - nt1.PurchaseYear = 1; 

--Solution 2:
WITH NewTable AS (
	SELECT 
		STRFTIME('%Y', i.InvoiceDate) AS PurchaseYear, 
		SUM(il.Quantity) AS TotalSales
	FROM Invoice AS i
	INNER JOIN InvoiceLine AS il ON i.InvoiceId = il.InvoiceId
	INNER JOIN Track AS t ON il.TrackId = t.TrackId 
	INNER JOIN Genre AS g ON t.GenreId = g.GenreId
	WHERE LOWER(g.Name) == 'rock' 
	GROUP BY 1
)

SELECT 
	PurchaseYear AS Year, 
	LAG(TotalSales, 1) OVER(ORDER BY PurchaseYear ASC) AS PreviousYearSales,
	TotalSales AS CurrentYearSales, 
	ROUND((TotalSales - LAG(TotalSales, 1) OVER(ORDER BY PurchaseYear ASC)) * 100.0 / LAG(TotalSales, 1) OVER(ORDER BY PurchaseYear ASC), 2) || '%' AS PercentIncrease
FROM NewTable;

-- Comment: From 2007 to 2011 there was a decline in sales of the rock genre. The biggest decrease was from 2007 to 2008 around 12.78%

SELECT
	SUM(CASE WHEN PurchaseYear = "2007" THEN 1 ELSE 0 END) AS "2007",
	SUM(CASE WHEN PurchaseYear = "2008" THEN 1 ELSE 0 END) AS "2008",
	SUM(CASE WHEN PurchaseYear = "2009" THEN 1 ELSE 0 END) AS "2009",
	SUM(CASE WHEN PurchaseYear = "2010" THEN 1 ELSE 0 END) AS "2010",
	SUM(CASE WHEN PurchaseYear = "2011" THEN 1 ELSE 0 END) AS "2011"
FROM (
	SELECT 
		STRFTIME('%Y', i.InvoiceDate) AS PurchaseYear, 
		g.Name
	FROM Invoice AS i
	INNER JOIN InvoiceLine AS il ON i.InvoiceId = il.InvoiceId
	INNER JOIN Track AS t ON il.TrackId = t.TrackId 
	INNER JOIN Genre AS g ON t.GenreId = g.GenreId
	WHERE PROPER(g.Name) = 'Rock'
) AS NewTable;



/* 3. Profit Analysis */


-- Question: How much did each customers spent per genre?

SELECT 
	c.CustomerId, 
	c.FirstName || ' ' || c.LastName AS CustomerName, 
	g.name AS Genre, 
	SUM(il.UnitPrice * il.Quantity) AS TotalSpent
FROM Customer AS c	
INNER JOIN Invoice AS i ON c.CustomerId = i.CustomerId
INNER JOIN InvoiceLine AS il ON i.InvoiceId = il.InvoiceId
INNER JOIN Track AS t ON il.TrackId = t.TrackId
INNER JOIN Genre AS g ON t.GenreId = g.GenreId
GROUP BY 1, 2, 3;

-- Penjualan dalam 6 bulan terakhir

SELECT * FROM Album

-- Calculate the total sales for each year.

SELECT * FROM Album

-- Identify the employee with the most sales.

SELECT * FROM Album

-- Find the employee who has the most customers assigned to them.

SELECT * FROM Album

-- Used to get the sale per unit per genre and percentage of sale

SELECT * FROM Album

-- Used to get the aggregated table of countries with one customers grouped under ‘Other’ as country name, total number of customers, total number of orders, total value of orders, average value of orders. Countries grouped in others are excluded in the analysis because of its limited data.

SELECT * FROM Album

-- Used to get the percentage of sale per media type

SELECT * FROM Album

-- Used to get all sales made by the sales agent

SELECT * FROM Album



/* 4. Employee Insights */


-- Give a table that consist of EmployeeId, and

WITH NewTable AS (
    SELECT
        e.EmployeeId,
        CAST(STRFTIME('%Y', i.InvoiceDate) AS INTEGER) AS Year
    FROM Employee AS e
    INNER JOIN Customer AS c ON e.EmployeeId = c.SupportRepId
    INNER JOIN Invoice AS i ON c.CustomerId = i.CustomerId
    WHERE UPPER(SUBSTR(e.Title, -5)) = "AGENT"
)

SELECT
    EmployeeID,
    SUM(CASE WHEN Year = 2007 THEN 1 ELSE 0 END) AS "2007",
    SUM(CASE WHEN Year = 2008 THEN 1 ELSE 0 END) AS "2008",
    SUM(CASE WHEN Year = 2009 THEN 1 ELSE 0 END) AS "2009",
    SUM(CASE WHEN Year = 2010 THEN 1 ELSE 0 END) AS "2010",
    SUM(CASE WHEN Year = 2011 THEN 1 ELSE 0 END) AS "2011"
FROM NewTable
GROUP BY 1
UNION ALL
SELECT
    "Total" AS EmployeeId,
    SUM(CASE WHEN Year = 2007 THEN 1 ELSE 0 END) AS "2007",
    SUM(CASE WHEN Year = 2008 THEN 1 ELSE 0 END) AS "2008",
    SUM(CASE WHEN Year = 2009 THEN 1 ELSE 0 END) AS "2009",
    SUM(CASE WHEN Year = 2010 THEN 1 ELSE 0 END) AS "2010",
    SUM(CASE WHEN Year = 2011 THEN 1 ELSE 0 END) AS "2011"
FROM NewTable;



/*
https://stackoverflow.com/questions/1130062/execution-sequence-of-group-by-having-and-where-clause-in-sql-server
https://github.com/ptyadana/Data-Analysis-for-Digital-Music-Store/blob/master/Chinook%20Digitial%20Music%20Store%20-%20Data%20Analysis.sql
https://m-soro.github.io/Business-Analytics/SQL-for-Data-Analysis/L4-Project-Query-Music-Store/
https://www.kaggle.com/code/alaasedeeq/chinook-sql 
 
DataViz
https://github.com/arjunchndr/Analyzing-Chinook-Database-using-SQL-and-Python/blob/master/Analyzing%20Chinook%20Database%20using%20SQL%20and%20Python.ipynb
https://rstudio-pubs-static.s3.amazonaws.com/636199_e04ca0dded894c23a17066dfad6ec9d3.html
*/

/*
========== Welcome to my SQL project! ==========

In this project, I will be querying various aspects of 
a music store dataset (source: DBeaver Sample Database). 
I'll divide this project into 4 main parts:
	1. Customer Data
	2. Music Trends
	3. Profit Analysis
	4. Employee Insights
	5. Artist Information
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
	ROUND((TotalSales - LAG(TotalSales, 1) OVER(ORDER BY PurchaseYear ASC)) * 100.0 / 
		LAG(TotalSales, 1) OVER(ORDER BY PurchaseYear ASC), 2) || '%' AS PercentIncrease
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
GROUP BY 1, 2, 3
ORDER BY 4 DESC;

-- Comment: Most of the genres with the most total spent are rock.


-- Question: Find the customer that has spent the most on music for each country.

WITH RECURSIVE
	tbl_customter_with_country AS (
		SELECT 
			c.CustomerId, 
			c.FirstName || ' ' || c.LastName AS Name, 
			i.BillingCountry AS Country, 
			SUM(i.total) AS TotalSpent
		FROM Customer AS c
		INNER JOIN Invoice AS i ON c.CustomerId = i.CustomerId
		GROUP BY 1, 2, 3
		ORDER BY 2, 3 DESC
		),
	tbl_country_max_spending AS (
		SELECT Country, MAX(TotalSpent) AS MaxSpent
		FROM tbl_customter_with_country
		GROUP BY 1)

SELECT tbl_cc.Country, tbl_cc.TotalSpent, tbl_cc.Name, tbl_cc.CustomerId
FROM tbl_customter_with_country AS tbl_cc
JOIN tbl_country_max_spending AS tbl_ms ON tbl_cc.Country = tbl_ms.Country
WHERE tbl_cc.TotalSpent = tbl_ms.MaxSpent
ORDER BY 1;

-- Comment: -


-- Question: How much was the total spent for the last 6 months (calculate from max date of InvoiceDate)?

-- Solution 1:
WITH MaxDateValue AS (
	SELECT MAX(InvoiceDate) AS MaxDate
	FROM Invoice
)

SELECT 
    STRFTIME('%Y-%m', i.InvoiceDate) AS YearMonth, 
    SUM(i.Total) AS TotalSpent,
    SUM(SUM(i.Total)) OVER(ORDER BY STRFTIME('%Y-%m', i.InvoiceDate)) AS CumulativeTotalSpent
FROM Invoice AS i
WHERE InvoiceDate BETWEEN (
        SELECT STRFTIME('%Y-%m', DATE(MaxDate, '-5 months', '-1 day', 'start of month'))
        FROM MaxDateValue
    ) AND (SELECT STRFTIME('%Y-%m', DATE(MaxDate, '1 months')) FROM MaxDateValue)
GROUP BY 1
ORDER BY 1 ASC;

-- Solution 2 (with Google Big Query & DATE_TRUNC):
WITH MaxDateValue AS (
	SELECT MAX(InvoiceDate) AS MaxDate
	FROM Invoice
)

SELECT 
	EXTRACT(MONTH FROM i.InvoiceDate) AS Month, 
	SUM(i.Total) AS TotalSpent,
	SUM(SUM(i.Total)) OVER(ORDER BY STRFTIME('%Y-%m', i.InvoiceDate)) AS CumulativeTotalSpent
FROM Invoice AS i
WHERE InvoiceDate BETWEEN DATE_SUB(DATE_TRUNC((SELECT MaxDate FROM MaxDateValue), MONTH), INTERVAL 6 MONTH) AND (SELECT MaxDate FROM MaxDateValue)
GROUP BY 1
ORDER BY 1 ASC;

-- Comment: There was a slight increase in income over 6 months. Moreover, in month 11, there was a big increase.


-- Question: Create a table that explains the total spent for each quarter of the year (can be improvised with another column).

SELECT
	STRFTIME('%Y', i.InvoiceDate) AS Year,
	CASE 
		WHEN STRFTIME('%m', i.InvoiceDate) BETWEEN '01' AND '03' THEN 'Q1'
        WHEN STRFTIME('%m', i.InvoiceDate) BETWEEN '04' AND '06' THEN 'Q2'
        WHEN STRFTIME('%m', i.InvoiceDate) BETWEEN '07' AND '09' THEN 'Q3'
        ELSE 'Q4'
	END AS QuarterPeriod,
	SUM(i.Total) AS TotalSpent,
	SUM(SUM(i.Total)) OVER(ORDER BY STRFTIME('%Y-%m', i.InvoiceDate)) AS CumulativeTotalSpent,
	ROUND((SUM(i.Total) - LAG(SUM(i.Total), 1) OVER(ORDER BY STRFTIME('%Y-%m', i.InvoiceDate))) * 100.0 / 
		LAG(SUM(i.Total), 1) OVER(ORDER BY STRFTIME('%Y-%m', i.InvoiceDate)), 2) || '%' AS PercentIncrease
FROM Invoice AS i
GROUP BY 1, 2;

-- Comment: -



/* 4. Employee Insights */


-- Question: Create a table that shows the number of customers assigned to each employee from 2007 - 2011.

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

-- Comment: The employee who has the most customers assigned to them is EmployeeId 3.



/* 5. Artist Information */


-- Question: Find artists with track averages that are longer than the overall track average.

SELECT 
	a.ArtistId, 
	AVG(t.Milliseconds) * 0.000016667 AS AverageTrackMinute -- 1 ms = 0.000016667 min		
FROM Album AS a
INNER JOIN Track AS t ON a.AlbumId = t.AlbumId
GROUP BY a.ArtistId
HAVING AVG(t.Milliseconds) > (SELECT 
								AVG(Milliseconds) 
							  FROM Track);

-- Comment: Most track minutes average around 10 minutes or less, but there are also ones that reach up to 20 or even 40 minutes.
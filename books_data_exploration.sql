-- select all data
SELECT * FROM books;

-- count of books on each shelf
SELECT 
	exclusive_shelf, 
	COUNT(*)
FROM
	books
GROUP BY
	exclusive_shelf 

-- check earliest and latest publication years to see range - note the latest year is 2025 because a book on my "to read" list hasn't yet been published
SELECT
	MIN(original_publication_year) AS earliest_year, 
	MAX(original_publication_year) AS latest_year
FROM
	books
WHERE
	original_publication_year != '' -- to remove rows where this is blank

-- total number of unique books, authors, publishers
SELECT 
	COUNT(*) AS total_records,  
	COUNT(DISTINCT book_id) AS total_books, 
	COUNT(DISTINCT author) AS total_authors, 
	COUNT(DISTINCT publisher) AS total_publishers
FROM
	books

-- sort based on number of books by each publisher
SELECT
	publisher, 
	COUNT(*) AS book_count
FROM
	books
GROUP BY
	publisher 
ORDER BY
	book_count DESC

-- some cleanup needed here as some publishers have multiple entries (eg. Simon Schuster UK, Simon & Schuster)
ALTER TABLE books ADD publisher_cl TEXT

UPDATE 
	books 
SET 
	publisher_cl = CASE 
						WHEN LOWER(publisher) LIKE '%penguin%' THEN 'Penguin'
						WHEN LOWER(publisher) LIKE '%simon%' THEN 'Simon & Schuster' -- confirmed no other publisers contain simon
						WHEN LOWER(publisher) LIKE 'unputdownable%' THEN 'Unputdownable'
						WHEN LOWER(publisher) LIKE 'orion publishing%' THEN 'Orion Publishing'
						WHEN LOWER(publisher) LIKE 'canongate books%' THEN 'Canongate Books'
						WHEN LOWER(publisher) LIKE 'bloomsbury%' THEN 'Bloomsbury Publishing'
						WHEN publisher = 'WINDMILL BOOKS' THEN 'Windmill Books'
						WHEN publisher = 'PROFILE BOOKS' THEN 'Profile Books'
						WHEN publisher = 'HACHETTE' THEN 'Hachette'
						ELSE publisher
					END

-- check publisher count with new cleanup column
SELECT
	publisher_cl, 
	COUNT(*) AS book_count
FROM
	books
GROUP BY
	publisher_cl 
ORDER BY
	book_count DESC

-- sort based on % of books from each publisher
WITH total_books AS (
SELECT
	COUNT(DISTINCT book_id) AS total_books
FROM
	books)

SELECT
	publisher_cl, 
	COUNT(*) as num_books, 
	CONCAT(ROUND(COUNT(*)*100.0/(SELECT * FROM total_books),2), '%') AS perc_total_books
FROM
	books
GROUP BY 1
ORDER BY 2 DESC, 1

-- min, max & avg  ratings
SELECT
	MIN(my_rating) AS min_rating, 
	MAX(my_rating) AS max_rating, 
	ROUND(AVG(my_rating),2) AS avg_rating
FROM
	books
WHERE
	exclusive_shelf  = 'read'

-- create a date-readable column from date_read - needs to be yyyy-MM-dd
ALTER TABLE books ADD formatted_date_read REAL

UPDATE books SET formatted_date_read = SUBSTR(date_read, 1, 4)||'-'||SUBSTR(date_read, 6, 2)||'-'||SUBSTR(date_read, 9, 2)

-- do same again with date_added column
ALTER TABLE books ADD formatted_date_added REAL

UPDATE books SET formatted_date_added = SUBSTR(date_added, 1, 4)||'-'||SUBSTR(date_added, 6, 2)||'-'||SUBSTR(date_added, 9, 2)

SELECT * FROM books

-- % of 5* reads per year
WITH total_books AS (
SELECT
	strftime('%Y', formatted_date_read) AS year,
	COUNT(DISTINCT book_id) AS total_reads
FROM
	books
WHERE
	exclusive_shelf = 'read'
GROUP BY
	year)	
	
SELECT
	strftime('%Y', formatted_date_read) AS year,
	COUNT(*) AS "5_star_reads", 
	tb.total_reads, 
	CONCAT(ROUND(COUNT(*)*100.0/tb.total_reads,2), '%') AS perc_5_star_reads
FROM
	books b
JOIN
	total_books tb ON tb.year = strftime('%Y', b.formatted_date_read)
WHERE
	exclusive_shelf = 'read'
AND 	
	my_rating = 5
GROUP BY 1
ORDER BY 1

-- stats per year - total read, 5* reads, avg rating per book, total pages read, avg pages per book
SELECT
	strftime('%Y', formatted_date_read) AS year,
	COUNT(*) AS total_read, 
	(SELECT
		COUNT(*)
	FROM
		books b2
	WHERE
		exclusive_shelf = 'read'
	AND
		my_rating = 5
	AND
		strftime('%Y', b2.formatted_date_read) = strftime('%Y', b.formatted_date_read)) AS "5_star_reads", 
	(SELECT
		AVG(my_rating)
	FROM
		books b3
	WHERE
		exclusive_shelf = 'read'
	AND
		strftime('%Y', b3.formatted_date_read) = strftime('%Y', b.formatted_date_read)) AS avg_rating, 
	(SELECT
		SUM(number_of_pages)
	FROM
		books b4
	WHERE
		exclusive_shelf = 'read'
	AND
		strftime('%Y', b4.formatted_date_read) = strftime('%Y', b.formatted_date_read)) AS total_pages_read, 
	(SELECT
		ROUND(AVG(number_of_pages),0)
	FROM
		books b5
	WHERE
		exclusive_shelf = 'read'
	AND
		strftime('%Y', b5.formatted_date_read) = strftime('%Y', b.formatted_date_read)) AS avg_pages_per_book
FROM
	books b
WHERE
	exclusive_shelf = 'read'
GROUP BY 1
ORDER BY 1

-- % of authors I've read more than one book of
WITH total_authors AS (
SELECT
	COUNT(DISTINCT author) AS total_authors
FROM
	books)

SELECT
	COUNT(DISTINCT author) AS num_authors, 
	CONCAT(ROUND(COUNT(DISTINCT author)*100.0/(SELECT * FROM total_authors), 2), '%') AS perc_total_authors
FROM
	(SELECT
		author, 
		COUNT(DISTINCT title) AS num_books
	FROM
		books
	WHERE 
		exclusive_shelf = 'read'
	GROUP BY 1
	HAVING num_books >1) AS A

-- window function: days between reads - assuming a new book is started after the previous without a gap, this gives the number of days taken to read each book
SELECT 
    title, 
    formatted_date_read AS date_read,
    LAG(formatted_date_read) OVER (ORDER BY formatted_date_read) AS previous_date,
    JULIANDAY(formatted_date_read) - JULIANDAY(LAG(formatted_date_read) OVER (ORDER BY formatted_date_read)) AS days_between_reads
FROM 
    books
WHERE 
	exclusive_shelf = 'read'
	
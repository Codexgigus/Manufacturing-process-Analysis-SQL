SELECT *
FROM [dbo].[manufacturing_parts]

--Checking null values --
Select item_no, COUNT(Item_no) as duplicatevalue
from [dbo].[manufacturing_parts]
group by item_no 
having count(item_no) > 1 ;

--Calculation of volume and ranking them-- And ranking Top 3 from each operator
With Volume_rank AS (
	Select 
		Operator,
		Item_no,
		Length,
		Width,
		height,
		Round((length * height * width),2) as Volume,
		Dense_rank () Over(Partition by operator order by Round((length * height * width),2) desc)as Item_rank 	
	From manufacturing_parts
)

Select 
	Operator,
	Item_no,
	Length,
	Width,
	height,
	Volume,
	Item_rank
From Volume_rank
where Item_rank <= 3 



--Operator whose average is more than overall average --

WITH Volume_CTE AS(
	Select 
		Operator,
		Item_no,
		Length,
		Width,
		height,
		Round((length * height * width),2) as Volume
	From manufacturing_parts

)

Select 
	Operator,
	AVG(Volume) as Average_volume 
From Volume_CTE
Group by Operator
Having  AVG(VOLUME) > (Select avg(Volume) from Volume_CTE);

--Calculating Average dimension per operator--
WITH Avg_Dim_CTE AS(
	Select  
		Operator,
		Length,
		Width,
		Height,
		Round(Avg(Length) OVER (PARTITION BY OPERATOR),2) AS Average_Operator_Length,
		Round(Avg(height) OVER (PARTITION BY OPERATOR),2) AS Average_Operator_height,
		Round(Avg(Width) OVER (PARTITION BY OPERATOR),2) AS Average_Operator_width

	From manufacturing_parts
)
--Calculating deviation per operator--
Select 
	Operator,
	Round([Length] - Average_Operator_Length,2) AS Length_Deviation,
	Round([Width] - Average_Operator_Width,2) AS Width_Deviation,
	Round([Height] - Average_Operator_Height,2) AS Height_Deviation

From Avg_Dim_CTE

--Calculating Z score -- making it CTE for furtehr use--
WITH ZSCORE_CTE AS(
SELECT
	 OPERATOR,
	 Avg_Volume,
	 STDV_Volume,
	 (volume - avg_volume)/ STDV_VOLUME as Z_Score
From (SELECT
		Operator,
		[Height],
		[Width],
		[Length],
		([Height] * [Length] * [Width]) AS Volume,
		ROUND(AVG([Height] * [Length] * [Width]) OVER (), 2) AS Avg_Volume,
		ROUND(STDEV([Height] * [Length] * [Width]) OVER (),2) AS STDV_VOLUME
	FROM manufacturing_parts) as Tbl

)
--Query for cheking outliers --
Select 
	Operator,
	Z_Score,
	(Case when z_score > 2 then 'Outlier' else 'Normal' end) as Position
From ZSCORE_CTE
Order by z_score desc

--Rolling average of legnth last 3 items--
SELECT 
	Operator,
	Length,
	Round(AVG(length) over (partition by operator order by operator rows between 2 preceding and current row),2) as rolling_avg_length
from manufacturing_parts 

--Percentage contribution of each operator to total volume--
SELECT 
	Operator,
	Total_operator_volume,
	Round(Total_operator_volume * 100 / SUM(Total_operator_volume) over (),2) as Contribution_percent

From (SELECT
		Operator,
		SUM(Length * Width * Height) AS Total_Operator_Volume
	FROM manufacturing_parts
	GROUP BY Operator) as Percent_table

--Count of items by size category--
 WITH CTE_SIZE AS(
	SELECT 
        Item_no,
        Operator,
        (Length * Height * Width) AS Volume,
        CASE 
            WHEN (Length * Height * Width) < 90000 THEN 'Small'
            WHEN (Length * Height * Width) < 100000 THEN 'Medium'
            ELSE 'Large'
        END AS Size_Category
    FROM manufacturing_parts
)

Select 
	size_category,
	Count(Item_no) as Total_items
From CTE_Size 
group by size_category

--Analyze the manufacturing_parts table and determine whether the manufacturing process is performing within acceptable control limits--
WITH Rolling_CTE AS(
	SELECT 
		Item_no,
		Operator,
		height,
		ROW_NUMBER()over(partition by operator order by item_no) as row_num,
		AVG(height) over(Partition by operator order by item_no rows between 4 preceding and current row) as Avg_height,
		STDEV(height)over(partition by operator order by item_no rows between 4 preceding and current row) as stdev_height
	From manufacturing_parts
)

	SELECT 
		operator,
		row_num,
		height, 
		Round(avg_height,2) as avg_height,
		Round(stdev_height,2) as stdev_height,
		Round(avg_height + (3 * stdev_height/SQRT(5)),2) as UCL,
		Round(avg_height - (3 * stdev_height/SQRT(5)),2) as LCL,
		Case 
			when height between avg_height + (3 * stdev_height/SQRT(5)) And avg_height - (3 * stdev_height/SQRT(5))
				Then 'True' else 'False' 
					end AS Alert
	from Rolling_CTE
	Where Row_num >= 5
	order by Item_no;
	

		

	











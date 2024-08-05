/* 
Cleaning Data with SQL Queries
Excel File which will be cleaned up: https://github.com/AlexTheAnalyst/PortfolioProjects/blob/main/Nashville%20Housing%20Data%20for%20Data%20Cleaning%20(reuploaded).xlsx
Side Note: In an already existing database, these steps should not be required since the database is already normalized
*/

/* DEACTIVATING SAFE MODE 
SET SQL_SAFE_UPDATES = 0;
-- REACTIVATING SAFE MODE
SET SQL_SAFE_UPDATES = 1; */


-- Gain a quick overview
SELECT *
FROM nashville_housing.nashville_housing_data;

/*
After looking at the dataset, we have to handle the NULL types in each column.
Another point to address is the splitting of the PropertyAddress, since it contains the street as well as the location, which should be separated.
*/

-- Populate Property Address data

SELECT *
FROM nashville_housing.nashville_housing_data
WHERE PropertyAddress IS NULL;

/* To handle NULL values in PropertyAddress you can e.g. look for duplicated ParcelIDs. If two or more exist, check if the duplicate does have a PropertyAddress */

UPDATE nashville_housing.nashville_housing_data AS a
JOIN nashville_housing.nashville_housing_data AS b
ON a.ParcelID = b.ParcelID
AND a.UniqueID != b.UniqueID
SET a.PropertyAddress = IFNULL(a.PropertyAddress, b.PropertyAddress)
WHERE a.PropertyAddress IS NULL
-- for safety warnings
AND a.UniqueID >= 0;

-- Next Step: Breaking up the column PropertyAddress into several columns (Address, City, State) to arrange it neatly. This can be done through separating at the comma in the column (e.g. in "1208 3RD AVE S, NASHVILLE", col1 = "1208 3RD AVE S" /// col2 = "Nashville")

--  Create Query to preview the split of the PropertyAddress column into two columns
SELECT
    SUBSTRING(PropertyAddress, 1, LOCATE(',', PropertyAddress) - 1) AS Address_Street,
    SUBSTRING(PropertyAddress, LOCATE(',', PropertyAddress, 1) + 1) AS Address_City
FROM nashville_housing_data;

-- Since you can't split a column in SQL, you have to create two new columns and fill in the values of the preview

ALTER TABLE nashville_housing_data
ADD COLUMN Property_Address_Street VARCHAR(255);

UPDATE nashville_housing_data
SET Address_Street = SUBSTRING(PropertyAddress, 1, LOCATE(',', PropertyAddress) - 1)
-- for safety warnings
WHERE UniqueID >= 0;

ALTER TABLE nashville_housing_data
ADD COLUMN Property_Address_City VARCHAR(255);

UPDATE nashville_housing_data
SET Address_City = SUBSTRING(PropertyAddress, LOCATE(',', PropertyAddress, 1) + 1)
WHERE UniqueID >= 0;

-- Now the same scheme can be applied to the OwnerAddress

SELECT OwnerAddress,
	SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ",", 1), ",", -1) AS Street,
    -- als Alternative für o.g. Query: SUBSTRING_INDEX(OwnerAddress, ",", 1),
    SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ",", 2), ",", -1) AS Town,
    SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ",", 3), ",", -1) AS State
FROM nashville_housing_data;

ALTER TABLE nashville_housing_data
	ADD COLUMN Owner_Address_Street VARCHAR(255),
	ADD COLUMN Owner_Address_Town VARCHAR(255),
	ADD COLUMN Owner_Address_State VARCHAR(255);

UPDATE nashville_housing_data
SET Owner_Address_Street = SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ",", 1), ",", -1)
-- for safety warnings
WHERE UniqueID >= 0;

UPDATE nashville_housing_data
SET Owner_Address_Town = SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ",", 2), ",", -1)
-- for safety warnings
WHERE UniqueID >= 0;

UPDATE nashville_housing_data
SET Owner_Address_State = SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ",", 3), ",", -1)
-- for safety warnings
WHERE UniqueID >= 0;

-- The next step should be to delete the original column "PropertyAddress"
 ALTER TABLE nashville_housing_data
 DROP COLUMN PropertyAddress;
 
SELECT *
FROM nashville_housing_data;

/* As it can be seen in the following query 

SELECT DISTINCT SoldAsVacant, COUNT(SoldAsVacant) AS num_sav
FROM nashville_housing_data
GROUP BY SoldAsVacant
Order BY num_sav;

It is shown that we have 1. do have "Y" (52), "N" (390), "Yes" and "No".
Since we do have way more "Yes" (4291) and "No" (49469) values, we should unify the column by replacing the "Y" and "N" values with "Yes" respective "No" */

UPDATE nashville_housing_data
SET SoldAsVacant = 
CASE 
	WHEN SoldAsVacant = "Y" THEN "Yes"
    WHEN SoldAsVacant = "N" THEN "No"
    ELSE SoldAsVacant
    END
WHERE UniqueID >= 0;
-- 442 rows affected, which represents all "Y" values (52) and all "N" values (390)
-- Now we can also delete the original column "OwnerAddress"

ALTER TABLE nashville_housing_data
DROP COLUMN OwnerAddress;


-- To further clean the dataset we have to check for duplicate values

WITH RowNumCTE AS(
SELECT *, ROW_NUMBER() OVER (
			PARTITION BY ParcelID,
						 PropertyAddress,
                         SalePrice,
                         SaleDate,
                         LegalReference
                         ORDER BY UniqueID) AS row_num

FROM nashville_housing_data
)
SELECT *
FROM RowNumCTE
WHERE row_num > 1;

-- Delete any duplicate rows

DELETE a
FROM Nashville_Housing_Data a
JOIN (
    SELECT UniqueID
    FROM (
        SELECT UniqueID,
               ROW_NUMBER() OVER (
               PARTITION BY ParcelID,
							PropertyAddress,
                            SaleDate,
                            SalePrice,
                            LegalReference
							ORDER BY UniqueID) AS row_num
		FROM Nashville_Housing_Data
    ) temp
    WHERE temp.row_num > 1
) b ON a.UniqueID = b.UniqueID;

-- Now the dataset is finally standardized and cleaned as far as possible. There are still a lot of NULL values, especially in the OwnerName columns, which therefore has an influence on Owner_Address_Street etc. To clean it up even further you might consider to drop those columns as well if necessary.


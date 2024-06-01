IF OBJECT_ID('dbo.DimEmployee', 'U') IS NOT NULL 
    DROP TABLE dbo.DimEmployee;

CREATE TABLE dbo.DimEmployee (
    Employee INT PRIMARY KEY,
    FirstName NVARCHAR(50),
    MiddleName NVARCHAR(50),
    LastName NVARCHAR(50),
    FullName NVARCHAR(150),
    AddressID INT,
    City NVARCHAR(50),
    Job NVARCHAR(100),
    BirthDate DATE,
    Age INT,
    Gender NVARCHAR(1),
    DepartmentID INT,
    Department NVARCHAR(100),
    Rate DECIMAL(10, 2),
    WorkExperience INT
);

-- Insert data into DimEmployee table
WITH LatestDepartmentHistory AS (
    SELECT 
        edh.BusinessEntityID,
        edh.DepartmentID,
        edh.StartDate,
        edh.EndDate,
        ROW_NUMBER() OVER (PARTITION BY edh.BusinessEntityID ORDER BY edh.EndDate DESC) AS rn
    FROM 
        HumanResources.EmployeeDepartmentHistory AS edh
)
INSERT INTO dbo.DimEmployee (
    Employee,
    FirstName,
    MiddleName,
    LastName,
    FullName,
    AddressID,
    City,
    Job,
    BirthDate,
    Age,
    Gender,
    DepartmentID,
    Department,
    Rate,
    WorkExperience
)
SELECT
    p.BusinessEntityID AS Employee,
    p.FirstName,
    p.MiddleName,
    p.LastName,
    CONCAT(p.FirstName, ' ', COALESCE(p.MiddleName + ' ', ''), p.LastName) AS FullName,
    bea.AddressID,
    a.City,
    e.JobTitle AS Job,
    e.BirthDate,
    DATEDIFF(YEAR, e.BirthDate, GETDATE()) - 
      CASE 
        WHEN MONTH(e.BirthDate) > MONTH(GETDATE()) 
            OR (MONTH(e.BirthDate) = MONTH(GETDATE()) AND DAY(e.BirthDate) > DAY(GETDATE())) 
        THEN 1 ELSE 0 END AS Age,
    e.Gender,
    ldh.DepartmentID,
    d.Name AS Department,
    eph.Rate,
    DATEDIFF(YEAR, ldh.StartDate, ISNULL(ldh.EndDate, GETDATE())) - 
      CASE 
        WHEN MONTH(ldh.StartDate) > MONTH(ISNULL(ldh.EndDate, GETDATE())) 
            OR (MONTH(ldh.StartDate) = MONTH(ISNULL(ldh.EndDate, GETDATE())) AND DAY(ldh.StartDate) > DAY(ISNULL(ldh.EndDate, GETDATE()))) 
        THEN 1 ELSE 0 END AS WorkExperience
FROM
    Person.Person AS p
    INNER JOIN Person.BusinessEntityAddress AS bea ON p.BusinessEntityID = bea.BusinessEntityID
    INNER JOIN Person.Address AS a ON bea.AddressID = a.AddressID
    INNER JOIN HumanResources.Employee AS e ON p.BusinessEntityID = e.BusinessEntityID
    INNER JOIN LatestDepartmentHistory AS ldh ON e.BusinessEntityID = ldh.BusinessEntityID AND ldh.rn = 1
    INNER JOIN HumanResources.Department AS d ON ldh.DepartmentID = d.DepartmentID
    INNER JOIN HumanResources.EmployeePayHistory AS eph ON e.BusinessEntityID = eph.BusinessEntityID
WHERE
    eph.RateChangeDate = (
        SELECT MAX(eph2.RateChangeDate)
        FROM HumanResources.EmployeePayHistory AS eph2
        WHERE eph2.BusinessEntityID = eph.BusinessEntityID
    )
ORDER BY
    p.BusinessEntityID;

SELECT * FROM dbo.DimEmployee;

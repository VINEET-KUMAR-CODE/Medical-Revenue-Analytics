use healthcare;

-- =============================================================================
-- Query 1 – overall Summary Dashboard 
-- Task
-- Generate a comprehensive executive-level Healthcare Revenue Cycle (RCM) summary
-- by combining financial, operational, claim quality, payment, and collection KPIs
-- into a single dashboard-ready report.
-- =============================================================================

SELECT

/* ============================================================================
   Volume KPIs
============================================================================ */

COUNT(DISTINCT Claim_ID) AS Total_Claims,

COUNT(DISTINCT Patient_ID) AS Total_Patients,

COUNT(DISTINCT Provider_ID) AS Total_Providers,

COUNT(DISTINCT Insurance_Company) AS Total_Insurance_Companies,

COUNT(DISTINCT Department_Name) AS Total_Departments,

/* ============================================================================
   Financial KPIs
============================================================================ */

ROUND(SUM(Net_Billed_Amount),2) AS Total_Revenue,

ROUND(SUM(Total_Collections_Posted),2) AS Total_Collections,

ROUND(SUM(Outstanding_AR_Balance),2) AS Outstanding_AR,

ROUND(SUM(Write_Off_Amount),2) AS Total_Write_Off,

ROUND(AVG(Net_Billed_Amount),2) AS Avg_Revenue_Per_Claim,

ROUND(AVG(Total_Collections_Posted),2) AS Avg_Collection_Per_Claim,

ROUND(AVG(Operating_Margin_Percentage),2) AS Avg_Operating_Margin,

/* ============================================================================
   Collection KPIs
============================================================================ */

ROUND(
    SUM(Total_Collections_Posted)
    /
    NULLIF(SUM(Net_Billed_Amount),0)
    *100
,2) AS Collection_Rate,

ROUND(
    SUM(Outstanding_AR_Balance)
    /
    NULLIF(SUM(Net_Billed_Amount),0)
    *100
,2) AS Outstanding_AR_Rate,

ROUND(
    SUM(Write_Off_Amount)
    /
    NULLIF(SUM(Net_Billed_Amount),0)
    *100
,2) AS Write_Off_Rate,

/* ============================================================================
   Claim Quality KPIs
============================================================================ */

SUM(
CASE
WHEN Adjudication_Decision_Status IN
(
'Fully Approved',
'Conditionally Approved'
)
THEN 1
ELSE 0
END
) AS Approved_Claims,

SUM(
CASE
WHEN Adjudication_Decision_Status = 'Rejected at Clearinghouse'
THEN 1
ELSE 0
END
) AS Rejected_Claims,

SUM(
CASE
WHEN Adjudication_Decision_Status = 'Payer Information Request'
THEN 1
ELSE 0
END
) AS Information_Request_Claims,

ROUND(
SUM(
CASE
WHEN Adjudication_Decision_Status IN
(
'Fully Approved',
'Conditionally Approved'
)
THEN 1
ELSE 0
END
)
/
COUNT(*)
*100
,2) AS Approval_Rate,

ROUND(
SUM(
CASE
WHEN Adjudication_Decision_Status = 'Rejected at Clearinghouse'
THEN 1
ELSE 0
END
)
/
COUNT(*)
*100
,2) AS Rejection_Rate,

/* ============================================================================
   Operational KPIs
============================================================================ */

ROUND(AVG(Days_to_Payment_Settlement),2) AS Avg_Payment_Days,

ROUND(AVG(Quality_Score),2) AS Avg_Quality_Score

FROM `Master table`

WHERE Adjudication_Decision_Status IS NOT NULL

HAVING Total_Claims > 0;



-- =========================================================
-- Query 2 – Department Performance Scorecard 
-- Task 
-- Analyze department-wise financial and operational performance by measuring revenue, 
-- collections, productivity, denial rate, payment efficiency, and profitability. 
-- =========================================================

SELECT

Department_Name,

COUNT(DISTINCT Claim_ID) AS Total_Claims,
COUNT(DISTINCT Patient_ID) AS Total_Patients,

ROUND(SUM(Net_Billed_Amount),2) AS Revenue,
ROUND(SUM(Total_Collections_Posted),2) AS Collections,
ROUND(SUM(Outstanding_AR_Balance),2) AS Outstanding_AR,

ROUND(AVG(Days_to_Payment_Settlement),2) AS Avg_Payment_Days,
ROUND(AVG(Operating_Margin_Percentage),2) AS Margin,

ROUND(
    SUM(Total_Collections_Posted)
    / NULLIF(SUM(Net_Billed_Amount),0)
    * 100,2
) AS Collection_Rate,

ROUND(
    SUM(
        CASE
            WHEN Adjudication_Decision_Status = 'Denied'
            THEN 1
            ELSE 0
        END
    ) / COUNT(*) * 100,2
) AS Denial_Rate,

SUM(
    CASE
        WHEN Days_to_Payment_Settlement <= 30
        THEN 1
        ELSE 0
    END
) AS Paid_Within_30_Days,

CASE
    WHEN AVG(Operating_Margin_Percentage) >= 30 THEN 'Excellent'
    WHEN AVG(Operating_Margin_Percentage) >= 20 THEN 'Good'
    WHEN AVG(Operating_Margin_Percentage) >= 10 THEN 'Average'
    ELSE 'Needs Improvement'
END AS Department_Performance

FROM `Master table`

GROUP BY Department_Name

ORDER BY Revenue DESC;


-- ===============================================
-- Query 3 – Provider Productivity & Performance Ranking 
-- Task 
-- Rank healthcare providers based on claim volume, revenue, collections, operating 
-- margin, and payment efficiency using SQL Window Functions. 
-- ================================================

WITH Provider_KPI AS
(
    SELECT
        Provider_ID,
        Provider_Name,
        Department_Name,

        COUNT(DISTINCT Claim_ID) AS Total_Claims,

        ROUND(SUM(Net_Billed_Amount),2) AS Revenue,
        ROUND(SUM(Total_Collections_Posted),2) AS Collections,
        ROUND(AVG(Operating_Margin_Percentage),2) AS Margin,
        ROUND(AVG(Days_to_Payment_Settlement),2) AS Avg_Payment_Days,

        ROUND(
            SUM(Total_Collections_Posted)
            / NULLIF(SUM(Net_Billed_Amount),0)
            * 100,2
        ) AS Collection_Rate

    FROM `Master table`

    GROUP BY
        Provider_ID,
        Provider_Name,
        Department_Name
)

SELECT
    *,

    ROW_NUMBER() OVER(
        ORDER BY Revenue DESC
    ) AS Revenue_Row_Number,

    RANK() OVER(
        ORDER BY Revenue DESC
    ) AS Revenue_Rank,

    DENSE_RANK() OVER(
        ORDER BY Collections DESC
    ) AS Collection_Rank

FROM Provider_KPI

ORDER BY Revenue DESC;



-- =====================================================================
-- Query 4 – Insurance Company Performance Analysis
-- Task
-- Evaluate insurance company performance by comparing claim volume, revenue,
-- collections, approval rate, denial rate, and collection efficiency.
-- =====================================================================

SELECT

    Insurance_Company,

    COUNT(DISTINCT Claim_ID) AS Total_Claims,

    ROUND(SUM(Net_Billed_Amount),2) AS Revenue,

    ROUND(SUM(Total_Collections_Posted),2) AS Collections,

    ROUND(
        SUM(Total_Collections_Posted)
        / NULLIF(SUM(Net_Billed_Amount),0) * 100,2
    ) AS Collection_Rate,

    ROUND(
        SUM(
            CASE
                WHEN Adjudication_Decision_Status IN
                (
                    'Fully Approved',
                    'Conditionally Approved'
                )
                THEN 1
                ELSE 0
            END
        ) / COUNT(*) * 100,2
    ) AS Approval_Rate,

    ROUND(
        SUM(
            CASE
                WHEN Adjudication_Decision_Status = 'Rejected at Clearinghouse'
                THEN 1
                ELSE 0
            END
        ) / COUNT(*) * 100,2
    ) AS Denial_Rate,

    ROUND(AVG(Days_to_Payment_Settlement),2) AS Avg_Payment_Days,

    CASE
        WHEN AVG(Days_to_Payment_Settlement) <= 30 THEN 'Excellent'
        WHEN AVG(Days_to_Payment_Settlement) <= 45 THEN 'Good'
        WHEN AVG(Days_to_Payment_Settlement) <= 60 THEN 'Average'
        ELSE 'Poor'
    END AS Insurance_Performance

FROM `Master table`

GROUP BY Insurance_Company

ORDER BY Revenue DESC;


-- ===================================================
-- Query 5 – Claim Aging Analysis Task 
-- Analyze outstanding claims by aging buckets to identify delayed payments and Accounts 
-- Receivable (AR) risk.
-- ===================================================

SELECT

CASE
    WHEN Days_to_Payment_Settlement <= 30 THEN '0-30 Days'
    WHEN Days_to_Payment_Settlement <= 60 THEN '31-60 Days'
    WHEN Days_to_Payment_Settlement <= 90 THEN '61-90 Days'
    ELSE '90+ Days'
END AS Aging_Bucket,

COUNT(*) AS Total_Claims,

ROUND(SUM(Net_Billed_Amount),2) AS Revenue,

ROUND(SUM(Outstanding_AR_Balance),2) AS Outstanding_AR,

ROUND(AVG(Days_to_Payment_Settlement),2) AS Avg_Days,

ROUND(AVG(Operating_Margin_Percentage),2) AS Avg_Margin

FROM `Master table`

GROUP BY Aging_Bucket

ORDER BY Avg_Days;



-- ==========================================================
-- Query 6 – Revenue Leakage Investigation 
-- Task 
-- Identify providers with the highest revenue leakage by comparing billed amounts against 
-- collected amounts. 
-- =========================================================

WITH Revenue_Analysis AS
(
    SELECT
        Provider_Name,

        SUM(Net_Billed_Amount) AS Revenue,
        SUM(Total_Collections_Posted) AS Collections,

        SUM(Net_Billed_Amount) - SUM(Total_Collections_Posted) AS Revenue_Leakage

    FROM `Master table`

    GROUP BY Provider_Name
)

SELECT

    Provider_Name,

    ROUND(Revenue,2) AS Revenue,
    ROUND(Collections,2) AS Collections,
    ROUND(Revenue_Leakage,2) AS Revenue_Leakage,

    ROUND(
        Revenue_Leakage
        / NULLIF(Revenue,0) * 100,2
    ) AS Leakage_Percentage,

    DENSE_RANK() OVER(
        ORDER BY Revenue_Leakage DESC
    ) AS Leakage_Rank

FROM Revenue_Analysis

ORDER BY Revenue_Leakage DESC;


-- =================================================
-- Query 7 – Financial Health Score Dashboard 
-- Task 
-- Calculate an overall financial health score by combining collection rate, operating 
-- margin, payment speed, and denial performance.
-- ================================================

WITH Financial_Score AS
(
SELECT

ROUND(
(
(SUM(Total_Collections_Posted)
/ NULLIF(SUM(Net_Billed_Amount),0))*40

+

(AVG(Operating_Margin_Percentage)/100)*30

+

((100-LEAST(AVG(Days_to_Payment_Settlement),100))/100)*20

+

(
(
100-
(
SUM(
CASE
WHEN Adjudication_Decision_Status='Denied'
THEN 1
ELSE 0
END
)
/COUNT(*)*100
)
)/100
)*10

)
,2
) AS Financial_Health_Score

FROM `Master table`
)

SELECT
Financial_Health_Score,

CASE
    WHEN Financial_Health_Score >= 90 THEN 'Excellent'
    WHEN Financial_Health_Score >= 80 THEN 'Very Good'
    WHEN Financial_Health_Score >= 70 THEN 'Good'
    WHEN Financial_Health_Score >= 60 THEN 'Average'
    ELSE 'Needs Improvement'
END AS Financial_Status

FROM Financial_Score;


-- ==============================================================
-- Query 8 – Provider Benchmarking & Performance Classification 
-- Task 
-- Benchmark healthcare providers using revenue quartiles and classify them into 
-- performance tiers for executive comparison.
-- ============================================================

WITH Provider_KPI AS
(
    SELECT
        Provider_Name,
        COUNT(DISTINCT Claim_ID) AS Total_Claims,
        SUM(Net_Billed_Amount) AS Revenue,
        SUM(Total_Collections_Posted) AS Collections,
        AVG(Operating_Margin_Percentage) AS Margin

    FROM `Master table`

    GROUP BY Provider_Name
)

SELECT
    Provider_Name,
    Total_Claims,

    ROUND(Revenue,2) AS Revenue,

    ROUND(Collections,2) AS Collections,

    ROUND(Margin,2) AS Margin,

    NTILE(4) OVER
    (
        ORDER BY Revenue DESC
    ) AS Revenue_Quartile,

    CASE
        WHEN NTILE(4) OVER (ORDER BY Revenue DESC) = 1 THEN 'Top Performer'
        WHEN NTILE(4) OVER (ORDER BY Revenue DESC) = 2 THEN 'High Performer'
        WHEN NTILE(4) OVER (ORDER BY Revenue DESC) = 3 THEN 'Average Performer'
        ELSE 'Needs Improvement'
    END AS Performance_Category

FROM Provider_KPI

ORDER BY Revenue DESC;


-- ===========================================================
-- Query 9 – Executive KPI Dashboard Dataset
-- Task
-- Create an executive-ready KPI dataset by combining provider, department, and insurance
-- performance into a single dashboard-ready report.
-- ===========================================================

WITH Department_KPI AS
(
    SELECT
        Department_Name,
        COUNT(DISTINCT Claim_ID) AS Total_Claims,
        SUM(Net_Billed_Amount) AS Revenue,
        SUM(Total_Collections_Posted) AS Collections,
        AVG(Operating_Margin_Percentage) AS Margin,
        SUM(Outstanding_AR_Balance) AS Outstanding_AR

    FROM `Master table`

    GROUP BY Department_Name
),

Provider_KPI AS
(
    SELECT
        Department_Name,
        COUNT(DISTINCT Provider_ID) AS Total_Providers,
        AVG(Quality_Score) AS Satisfaction,
        AVG(Days_to_Payment_Settlement) AS Avg_Payment_Days

    FROM `Master table`

    GROUP BY Department_Name
),

Insurance_KPI AS
(
    SELECT
        Department_Name,

        ROUND(
            SUM(
                CASE
                    WHEN Adjudication_Decision_Status IN
                    (
                        'Fully Approved',
                        'Conditionally Approved'
                    )
                    THEN 1
                    ELSE 0
                END
            ) / COUNT(*) * 100,
        2) AS Approval_Rate,

        ROUND(
            SUM(
                CASE
                    WHEN Adjudication_Decision_Status = 'Rejected at Clearinghouse'
                    THEN 1
                    ELSE 0
                END
            ) / COUNT(*) * 100,
        2) AS Denial_Rate

    FROM `Master table`

    GROUP BY Department_Name
)

SELECT

    d.Department_Name,

    d.Total_Claims,

    p.Total_Providers,

    ROUND(d.Revenue,2) AS Revenue,

    ROUND(d.Collections,2) AS Collections,

    ROUND(d.Outstanding_AR,2) AS Outstanding_AR,

    ROUND(d.Margin,2) AS Margin,

    ROUND(p.Satisfaction,2) AS Satisfaction,

    ROUND(p.Avg_Payment_Days,2) AS Avg_Payment_Days,

    i.Approval_Rate,

    i.Denial_Rate,

    ROUND(
        d.Collections
        / NULLIF(d.Revenue,0) * 100,
    2) AS Collection_Rate

FROM Department_KPI d

INNER JOIN Provider_KPI p
ON d.Department_Name = p.Department_Name

INNER JOIN Insurance_KPI i
ON d.Department_Name = i.Department_Name

ORDER BY Revenue DESC;


-- ===========================================================================
-- Query 10 – End-to-End Healthcare Revenue Cycle (RCM) Funnel Analysis
-- Task
-- Analyze the complete Healthcare Revenue Cycle from Claim Creation
-- to Final Payment using Claim-Level Funnel KPIs.
-- ===========================================================================

WITH RCM_Funnel AS
(
    SELECT


        COUNT(DISTINCT Claim_ID) AS Total_Claims,


        COUNT(DISTINCT Patient_ID) AS Registered_Patients,


        COUNT(
            DISTINCT CASE
            WHEN Insurance_Coverage_Verification =
            'Active Coverage Verified'
            THEN Claim_ID
            END
        ) AS Insurance_Verified,


        COUNT(
            DISTINCT CASE
            WHEN Payer_Receipt_Acknowledgement IN
            (
                '999 Acknowledgement Received',
                'TA1 Interchange Accepted'
            )
            THEN Claim_ID
            END
        ) AS Claims_Submitted,


        COUNT(
            DISTINCT CASE
            WHEN Adjudication_Decision_Status IN
            (
                'Fully Approved',
                'Conditionally Approved'
            )
            THEN Claim_ID
            END
        ) AS Claims_Approved,


        COUNT(
            DISTINCT CASE
            WHEN Adjudication_Decision_Status =
            'Rejected at Clearinghouse'
            THEN Claim_ID
            END
        ) AS Claims_Rejected,


        COUNT(
            DISTINCT CASE
            WHEN Adjudication_Decision_Status =
            'Payer Information Request'
            THEN Claim_ID
            END
        ) AS Information_Request_Claims,


        COUNT(
            DISTINCT CASE
            WHEN Outstanding_AR_Balance = 0
            THEN Claim_ID
            END
        ) AS Claims_Paid,


        ROUND(SUM(Net_Billed_Amount),2) AS Total_Billed,


        ROUND(SUM(Total_Collections_Posted),2) AS Total_Collections,


        ROUND(SUM(Outstanding_AR_Balance),2) AS Outstanding_AR,


        ROUND(SUM(Write_Off_Amount),2) AS Total_Write_Off


    FROM `Master table`
),



RCM_Calculated_KPI AS
(
    SELECT


        *,


        ROUND(
            Insurance_Verified /
            NULLIF(Total_Claims,0) *100,
        2) AS Insurance_Verification_Rate,


        ROUND(
            Claims_Submitted /
            NULLIF(Total_Claims,0) *100,
        2) AS Submission_Rate,


        ROUND(
            Claims_Approved /
            NULLIF(Claims_Submitted,0) *100,
        2) AS Approval_Rate,


        ROUND(
            Claims_Rejected /
            NULLIF(Claims_Submitted,0) *100,
        2) AS Rejection_Rate,


        ROUND(
            Information_Request_Claims /
            NULLIF(Claims_Submitted,0) *100,
        2) AS Information_Request_Rate,


        ROUND(
            Claims_Paid /
            NULLIF(Claims_Approved,0) *100,
        2) AS Payment_Conversion_Rate,


        ROUND(
            Total_Collections /
            NULLIF(Total_Billed,0) *100,
        2) AS Collection_Rate,


        ROUND(
            Outstanding_AR /
            NULLIF(Total_Billed,0) *100,
        2) AS AR_Percentage,


        ROUND(
            Total_Write_Off /
            NULLIF(Total_Billed,0) *100,
        2) AS Write_Off_Rate


    FROM RCM_Funnel
)



SELECT


    *,


    ROUND(
        100 - Collection_Rate,
    2) AS Revenue_Leakage_Percentage,


    CASE


        WHEN Collection_Rate >= 95
             AND Rejection_Rate <= 5
        THEN 'Excellent Revenue Cycle'


        WHEN Collection_Rate >= 90
        THEN 'Healthy Revenue Cycle'


        WHEN Collection_Rate >= 80
        THEN 'Average Revenue Cycle'


        ELSE 'Critical Improvement Required'


    END AS Overall_RCM_Status


FROM RCM_Calculated_KPI;

-- ===============================================================
-- Query 11 = Financial Performance, Revenue & Risk Analysis
-- ===============================================================

WITH Business_Performance AS
(

SELECT

Department_Name,

Provider_Name,

Insurance_Company,

COUNT(DISTINCT Claim_ID) AS Total_Claims,

ROUND(SUM(Net_Billed_Amount),2) AS Revenue,

ROUND(SUM(Total_Collections_Posted),2) AS Collections,

ROUND(SUM(Cost_of_Billing_Operations),2) AS Operating_Cost,

ROUND(SUM(Write_Off_Amount),2) AS Write_Off,

ROUND(
SUM(Net_Billed_Amount)
-
SUM(Cost_of_Billing_Operations)
,2
) AS Gross_Profit,

ROUND(
SUM(Total_Collections_Posted)
-
SUM(Cost_of_Billing_Operations)
-
SUM(Write_Off_Amount)
,2
) AS Net_Profit,

ROUND(AVG(Operating_Margin_Percentage),2) AS Margin,

ROUND(AVG(Days_to_Payment_Settlement),2) AS Avg_Payment_Days

FROM `Master table`

GROUP BY

Department_Name,
Provider_Name,
Insurance_Company

),

Executive_KPI AS
(

SELECT

*,

ROUND(
Collections
/
NULLIF(Revenue,0)
*100
,2
) AS Collection_Rate,

ROUND(
Net_Profit
/
NULLIF(Revenue,0)
*100
,2
) AS Net_Profit_Margin,

ROUND(
Write_Off
/
NULLIF(Revenue,0)
*100
,2
) AS Write_Off_Rate,

NTILE(4)
OVER
(
ORDER BY Net_Profit DESC
) AS Profitability_Quartile,

DENSE_RANK()
OVER
(
ORDER BY Net_Profit DESC
) AS Profit_Rank

FROM Business_Performance

),

Decision_Matrix AS
(

SELECT

*,

CASE

WHEN Collection_Rate >= 95
AND Net_Profit_Margin >= 30
AND Avg_Payment_Days <= 30

THEN 'Elite'

WHEN Collection_Rate >= 90
AND Net_Profit_Margin >= 20

THEN 'High Performer'

WHEN Collection_Rate >= 80

THEN 'Stable'

ELSE 'Needs Attention'

END AS Business_Category,

CASE

WHEN Write_Off_Rate >= 15
OR Avg_Payment_Days > 60

THEN 'High Risk'

WHEN Write_Off_Rate >= 8

THEN 'Medium Risk'

ELSE 'Low Risk'

END AS Risk_Level

FROM Executive_KPI

)

SELECT

Department_Name,

Provider_Name,

Insurance_Company,

Total_Claims,

Revenue,

Collections,

Operating_Cost,

Write_Off,

Gross_Profit,

Net_Profit,

Margin,

Collection_Rate,

Net_Profit_Margin,

Write_Off_Rate,

Avg_Payment_Days,

Profitability_Quartile,

Profit_Rank,

Business_Category,

Risk_Level

FROM Decision_Matrix

ORDER BY

Profit_Rank,
Collection_Rate DESC;


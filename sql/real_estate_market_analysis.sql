/*
Real Estate Market Analysis

Цель:
проанализировать рынок жилой недвижимости Санкт-Петербурга
и городов Ленинградской области по срокам активности объявлений
и сезонности публикаций/снятий.

Инструменты:
PostgreSQL, DBeaver, SQL.
*/


-- Задача 1: анализ времени активности объявлений

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),

filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND (
            (
                ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
                AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
            ) 
            OR ceiling_height IS NULL
        )
),

data_for_analysis AS (
    SELECT 
        fi.id,
        CASE 
            WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
            ELSE 'Ленинградская область' 
        END AS region_name,
        CASE 
            WHEN adv.days_exposition IS NULL THEN 'non category'
            WHEN adv.days_exposition BETWEEN 1 AND 30 THEN '1-30 days'
            WHEN adv.days_exposition BETWEEN 31 AND 90 THEN '31-90 days'
            WHEN adv.days_exposition BETWEEN 91 AND 180 THEN '91-180 days'
            WHEN adv.days_exposition >= 181 THEN '181+ days'
            ELSE 'non category'
        END AS activity_category,
        adv.last_price / f.total_area AS price_per_meter,
        f.total_area,
        f.rooms,
        f.balcony
    FROM filtered_id AS fi
    JOIN real_estate.advertisement AS adv ON fi.id = adv.id
    JOIN real_estate.flats AS f ON fi.id = f.id
    JOIN real_estate.city AS c ON f.city_id = c.city_id
    JOIN real_estate.type AS t ON f.type_id = t.type_id
    WHERE t.type = 'город'
      AND EXTRACT(YEAR FROM adv.first_day_exposition) BETWEEN 2015 AND 2018
)

SELECT 
    region_name,
    activity_category,
    COUNT(id) AS total_ads,
    ROUND(AVG(price_per_meter)::numeric, 2) AS avg_price_per_meter,
    ROUND(AVG(total_area)::numeric, 2) AS avg_area,
    ROUND(AVG(rooms)::numeric, 2) AS avg_rooms_count,
    ROUND(AVG(balcony)::numeric, 2) AS avg_balconies_count
FROM data_for_analysis 
GROUP BY 
    region_name,
    activity_category
ORDER BY 
    region_name DESC,
    activity_category;


-- Задача 2: анализ сезонности публикации и снятия объявлений

WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),

filtered_id AS (
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND (
            (
                ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
                AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)
            ) 
            OR ceiling_height IS NULL
        )
),

data_for_analysis AS (
    SELECT 
        filtered_id.id,
        advertisement.first_day_exposition,
        advertisement.first_day_exposition + advertisement.days_exposition * INTERVAL '1 day' AS removal_date,
        advertisement.last_price / flats.total_area AS price_per_meter,
        flats.total_area
    FROM filtered_id
    JOIN real_estate.advertisement ON filtered_id.id = advertisement.id
    JOIN real_estate.flats ON filtered_id.id = flats.id
    JOIN real_estate.type ON flats.type_id = type.type_id
    WHERE type.type = 'город'
      AND EXTRACT(YEAR FROM advertisement.first_day_exposition) BETWEEN 2015 AND 2018
),

published_stats AS (
    SELECT 
        EXTRACT(MONTH FROM first_day_exposition) AS month_number,
        COUNT(id) AS published_ads_count,
        ROUND(AVG(price_per_meter)::numeric, 2) AS pub_avg_price_per_meter,
        ROUND(AVG(total_area)::numeric, 2) AS pub_avg_area
    FROM data_for_analysis
    GROUP BY EXTRACT(MONTH FROM first_day_exposition)
),

removed_stats AS (
    SELECT 
        EXTRACT(MONTH FROM removal_date) AS month_number,
        COUNT(id) AS removed_ads_count,
        ROUND(AVG(price_per_meter)::numeric, 2) AS rem_avg_price_per_meter,
        ROUND(AVG(total_area)::numeric, 2) AS rem_avg_area
    FROM data_for_analysis
    WHERE removal_date IS NOT NULL
    GROUP BY EXTRACT(MONTH FROM removal_date)
)

SELECT 
    published_stats.month_number,
    published_stats.published_ads_count,
    removed_stats.removed_ads_count,
    published_stats.pub_avg_price_per_meter,
    removed_stats.rem_avg_price_per_meter,
    published_stats.pub_avg_area,
    removed_stats.rem_avg_area
FROM published_stats
JOIN removed_stats ON published_stats.month_number = removed_stats.month_number
ORDER BY published_stats.month_number;

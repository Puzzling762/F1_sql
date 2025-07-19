-- 	Constructor championship wins by year
WITH race_years AS (
    SELECT raceId, year
    FROM races
    WHERE year BETWEEN 1950 AND 2024
),

points_per_result AS (
    SELECT
        r.resultId,
        r.constructorId,
        r.driverId,
        r.raceId,
        CASE r.positionOrder
            WHEN 1 THEN 25
            WHEN 2 THEN 18
            WHEN 3 THEN 15
            WHEN 4 THEN 12
            WHEN 5 THEN 10
            WHEN 6 THEN 8
            WHEN 7 THEN 6
            WHEN 8 THEN 4
            WHEN 9 THEN 2
            WHEN 10 THEN 1
            ELSE 0
        END AS points
    FROM results r
),

constructor_points AS (
    SELECT 
        r.constructorId,
        ry.year,
        SUM(CASE r.positionOrder
            WHEN 1 THEN 25
            WHEN 2 THEN 18
            WHEN 3 THEN 15
            WHEN 4 THEN 12
            WHEN 5 THEN 10
            WHEN 6 THEN 8
            WHEN 7 THEN 6
            WHEN 8 THEN 4
            WHEN 9 THEN 2
            WHEN 10 THEN 1
            ELSE 0
        END) AS total_points
    FROM results r
    JOIN race_years ry ON r.raceId = ry.raceId
    GROUP BY r.constructorId, ry.year
),

constructor_champions AS (
    SELECT
        cp.year,
        cp.constructorId,
        cp.total_points,
        RANK() OVER(PARTITION BY cp.year ORDER BY cp.total_points DESC) AS pos
    FROM constructor_points cp
)

SELECT 
    cc.year,
    c.name AS constructor_name,
    cc.total_points
FROM constructor_champions cc
JOIN constructors c ON cc.constructorId = c.constructorId
WHERE cc.pos = 1
ORDER BY cc.year;

-- Constructor with highest average points per race
WITH race_years AS (
  SELECT raceId, year
  FROM races
  WHERE year BETWEEN 1950 AND 2024
),

constructor_points AS (
  SELECT 
    r.constructorId,
    ry.year,
    SUM(CASE r.positionOrder
        WHEN 1 THEN 25
        WHEN 2 THEN 18
        WHEN 3 THEN 15
        WHEN 4 THEN 12
        WHEN 5 THEN 10
        WHEN 6 THEN 8
        WHEN 7 THEN 6
        WHEN 8 THEN 4
        WHEN 9 THEN 2
        WHEN 10 THEN 1
        ELSE 0
    END) AS total_points
  FROM results r
  JOIN race_years ry ON r.raceId = ry.raceId
  GROUP BY r.constructorId, ry.year
),

race_counts AS (
  SELECT year, COUNT(*) AS race_count
  FROM races
  WHERE year BETWEEN 1950 AND 2024
  GROUP BY year
),

constructor_avg_points AS (
  SELECT 
    cp.constructorId,
    cp.year,
    cp.total_points,
    rc.race_count,
    1.0 * cp.total_points / rc.race_count AS avg_points_per_race
  FROM constructor_points cp
  JOIN race_counts rc ON cp.year = rc.year
)

SELECT 
  c.name AS constructor_name,
  ROUND(AVG(avg_points_per_race), 2) AS avg_points_across_seasons
FROM constructor_avg_points cap
JOIN constructors c ON cap.constructorId = c.constructorId
GROUP BY c.name
ORDER BY avg_points_across_seasons DESC
LIMIT 5;
-- Most dominant constructors by decade
WITH race_years AS (
  SELECT raceId, year
  FROM races
  WHERE year BETWEEN 1950 AND 2024
),

points_per_result AS (
  SELECT
    r.constructorId,
    ry.year,
    CASE r.positionOrder
      WHEN 1 THEN 25
      WHEN 2 THEN 18
      WHEN 3 THEN 15
      WHEN 4 THEN 12
      WHEN 5 THEN 10
      WHEN 6 THEN 8
      WHEN 7 THEN 6
      WHEN 8 THEN 4
      WHEN 9 THEN 2
      WHEN 10 THEN 1
      ELSE 0
    END AS points
  FROM results r
  JOIN race_years ry ON r.raceId = ry.raceId
),

points_by_decade AS (
  SELECT
    p.constructorId,
    FLOOR(p.year / 10) * 10 AS decade,
    SUM(p.points) AS total_points
  FROM points_per_result p
  GROUP BY p.constructorId, FLOOR(p.year / 10) * 10
),

ranked_constructors AS (
  SELECT 
    pd.decade,
    pd.constructorId,
    pd.total_points,
    RANK() OVER(PARTITION BY pd.decade ORDER BY pd.total_points DESC) AS constructor_rank
  FROM points_by_decade pd
)

SELECT 
  rc.decade,
  c.name AS constructor_name,
  rc.total_points
FROM ranked_constructors rc
JOIN constructors c ON rc.constructorId = c.constructorId
WHERE rc.constructor_rank = 1
ORDER BY rc.decade;

-- Constructor head-to-head (e.g., Ferrari vs Red Bull)
WITH constructor_season_points AS (
  SELECT 
    r.constructorId,
    c.name AS constructor_name,
    ra.year,
    SUM(
      CASE r.positionOrder
        WHEN 1 THEN 25
        WHEN 2 THEN 18
        WHEN 3 THEN 15
        WHEN 4 THEN 12
        WHEN 5 THEN 10
        WHEN 6 THEN 8
        WHEN 7 THEN 6
        WHEN 8 THEN 4
        WHEN 9 THEN 2
        WHEN 10 THEN 1
        ELSE 0
      END
    ) AS total_points
  FROM results r
  JOIN races ra ON r.raceId = ra.raceId
  JOIN constructors c ON r.constructorId = c.constructorId
  GROUP BY r.constructorId, c.name, ra.year
),
head_to_head AS (
  SELECT 
    a.constructor_name AS constructor_A,
    b.constructor_name AS constructor_B,
    a.year,
    a.total_points AS points_A,
    b.total_points AS points_B,
    CASE 
      WHEN a.total_points > b.total_points THEN 1
      ELSE 0
    END AS A_beats_B
  FROM constructor_season_points a
  JOIN constructor_season_points b 
    ON a.year = b.year AND a.constructor_name != b.constructor_name
)

SELECT 
  constructor_A,
  constructor_B,
  COUNT(*) AS seasons_compared,
  SUM(A_beats_B) AS A_wins,
  COUNT(*) - SUM(A_beats_B) AS B_wins
FROM head_to_head
GROUP BY constructor_A, constructor_B
ORDER BY A_wins DESC, seasons_compared DESC;

-- Best constructor-driver combos (Mercedes-Hamilton, Red Bull-Vettel, etc.)
SELECT 
  d.forename,
  d.surname,
  c.name AS constructor_name,
  CONCAT(d.forename, ' ', d.surname, ' - ', c.name) AS combo_name,
  COUNT(r.resultId) AS races_together,
  SUM(
    CASE r.positionOrder
      WHEN 1 THEN 25
      WHEN 2 THEN 18
      WHEN 3 THEN 15
      WHEN 4 THEN 12
      WHEN 5 THEN 10
      WHEN 6 THEN 8
      WHEN 7 THEN 6
      WHEN 8 THEN 4
      WHEN 9 THEN 2
      WHEN 10 THEN 1
      ELSE 0
    END
  ) AS total_points,
  SUM(CASE WHEN r.positionOrder = 1 THEN 1 ELSE 0 END) AS wins,
  SUM(CASE WHEN r.positionOrder <= 3 THEN 1 ELSE 0 END) AS podiums
FROM results r
JOIN drivers d ON r.driverId = d.driverId
JOIN constructors c ON r.constructorId = c.constructorId
GROUP BY d.forename,d.surname,c.name
ORDER BY total_points DESC
LIMIT 20;


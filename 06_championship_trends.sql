-- Step 1: Driver name view
CREATE OR REPLACE VIEW driver_details AS
SELECT 
  driverId,
  CONCAT(forename, ' ', surname) AS driver_name
FROM drivers;

-- Drivers who led championship but lost

WITH first_half_leader AS (
  SELECT * FROM (
    SELECT 
      r.year, 
      res.driverId, 
      dd.driver_name, 
      SUM(res.points) AS first_half_points,
      ROW_NUMBER() OVER (PARTITION BY r.year ORDER BY SUM(res.points) DESC) AS rn
    FROM results res
    JOIN races r ON res.raceId = r.raceId
    JOIN driver_details dd ON dd.driverId = res.driverId
    WHERE r.year >= 2010 AND r.round <= 10
    GROUP BY r.year, res.driverId, dd.driver_name
  ) ranked
  WHERE rn = 1
),
final_champion AS (
  SELECT * FROM (
    SELECT 
      r.year, 
      res.driverId, 
      dd.driver_name AS champion_name,
      SUM(res.points) AS full_season_points,
      ROW_NUMBER() OVER (PARTITION BY r.year ORDER BY SUM(res.points) DESC) AS rn
    FROM results res
    JOIN races r ON res.raceId = r.raceId
    JOIN driver_details dd ON dd.driverId = res.driverId
    WHERE r.year >= 2010
    GROUP BY r.year, res.driverId, dd.driver_name
  ) ranked
  WHERE rn = 1
)

SELECT 
  fh.year,
  fh.driver_name AS first_half_leader,
  fc.champion_name AS season_champion
FROM first_half_leader fh
JOIN final_champion fc ON fh.year = fc.year
ORDER BY fh.year;

-- Constructors with back-to-back titles
SELECT 
  r1.year AS current_year,
  c1.name AS constructor_name
FROM constructor_standings cs1
JOIN races r1 ON cs1.raceId = r1.raceId
JOIN constructors c1 ON cs1.constructorId = c1.constructorId
WHERE cs1.position = 1
  AND r1.raceId IN (SELECT MAX(raceId) FROM races GROUP BY year)
  AND EXISTS (
    SELECT 1
    FROM constructor_standings cs2
    JOIN races r2 ON cs2.raceId = r2.raceId
    WHERE cs2.position = 1
      AND cs2.constructorId = cs1.constructorId
      AND r2.year = r1.year - 1
      AND r2.raceId IN (SELECT MAX(raceId) FROM races GROUP BY year)
  )
ORDER BY r1.year;

-- Close title fights (final race deciders)

WITH last_race_per_year AS (
  SELECT year, MAX(raceId) AS last_raceId
  FROM races
  GROUP BY year
),

standings_last_race AS (
  SELECT 
    r.year,
    cs.constructorId,
    c.name AS constructor_name,
    cs.points
  FROM constructor_standings cs
  JOIN races r ON cs.raceId = r.raceId
  JOIN constructors c ON cs.constructorId = c.constructorId
  JOIN last_race_per_year lr ON r.raceId = lr.last_raceId
),

ranked_constructors AS (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY year ORDER BY points DESC) AS pos
  FROM standings_last_race
),

top_two AS (
  SELECT year, constructor_name, points, pos
  FROM ranked_constructors
  WHERE pos <= 2
)

SELECT 
  t1.year,
  t1.constructor_name AS winner,
  t2.constructor_name AS runner_up,
  t1.points AS winner_pts,
  t2.points AS runner_up_pts,
  (t1.points - t2.points) AS point_gap
FROM top_two t1
JOIN top_two t2 
  ON t1.year = t2.year AND t1.pos = 1 AND t2.pos = 2
WHERE (t1.points - t2.points) <= 10 
ORDER BY t1.year;


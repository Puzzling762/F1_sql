USE f1_analytics;
CREATE VIEW driver_details AS
SELECT 
  driverId,
  CONCAT(forename, ' ', surname) AS driver_name
FROM drivers;

SELECT 
  dd.driverId,
  dd.driver_name,
  COUNT(r.resultId) AS total_races,
  SUM(CASE WHEN r.position = 1 THEN 1 ELSE 0 END) AS wins,
  SUM(CASE WHEN r.position <= 3 THEN 1 ELSE 0 END) AS podiums
FROM results r
JOIN driver_details dd ON r.driverId = dd.driverId
GROUP BY dd.driverId,dd.driver_name
ORDER BY wins DESC;

-- Career points "Modern Points (25–18–15 system applied across all seasons)"
SELECT 
  dd.driverId,
  dd.driver_name,
  ROUND(SUM(
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
  ), 2) AS normalized_total_points,
  COUNT(CASE WHEN r.positionOrder = 1 THEN 1 END) AS total_wins
FROM results r
JOIN driver_Details dd ON r.driverId = dd.driverId
GROUP BY dd.driverId, dd.driver_name
ORDER BY normalized_total_points DESC
LIMIT 10;


-- Year wise Points+ Ranking Progression
SELECT 
  d.driverId,
  dd.driver_name,
  ra.year,
  ds.points,
  ds.position AS final_rank
FROM driver_standings ds
JOIN drivers d ON ds.driverId = d.driverId
JOIN driver_details dd ON dd.driverId = d.driverId
JOIN races ra ON ds.raceId = ra.raceId
WHERE ra.year >= 2010
  AND ra.raceId IN (
    SELECT MAX(raceId)
    FROM races
    GROUP BY year
  )
ORDER BY driver_name, ra.year;

-- DNF Count and Percentage (using status table)
SELECT 
  d.driverId,
  dd.driver_name,
  COUNT(*) AS total_races,
  SUM(CASE 
        WHEN s.status LIKE '%accident%' OR s.status LIKE '%disqualified%' 
          OR s.status LIKE '%engine%' OR s.status LIKE '%gearbox%' 
          OR s.status LIKE '%suspension%' OR s.status LIKE '%retired%' 
          OR s.status LIKE '%did not finish%' 
        THEN 1 ELSE 0 
      END) AS dnf_count,
  ROUND(
    100 * SUM(CASE 
               WHEN s.status LIKE '%accident%' OR s.status LIKE '%disqualified%' 
                 OR s.status LIKE '%engine%' OR s.status LIKE '%gearbox%' 
                 OR s.status LIKE '%suspension%' OR s.status LIKE '%retired%' 
                 OR s.status LIKE '%did not finish%' 
               THEN 1 ELSE 0 
             END) / COUNT(*), 2) AS dnf_percentage
FROM 
  results r
JOIN 
  drivers d ON r.driverId = d.driverId
JOIN 
  driver_details dd ON dd.driverId = d.driverId
JOIN 
  status s ON r.statusId = s.statusId
GROUP BY 
  d.driverId, dd.driver_name
ORDER BY 
  dnf_percentage DESC
  LIMIT 20;
-- Grid start vs finish position (from results)
SELECT 
  dd.driverId,
  dd.driver_name,
  ROUND(AVG(r.grid - r.positionOrder), 2) AS avg_positions_gained
FROM results r
JOIN driver_Details dd ON r.driverId = dd.driverId
JOIN races ra on ra.raceId=r.raceId
WHERE r.grid > 0 AND r.positionOrder > 0  
	AND ra.year BETWEEN 2019 and 2024
GROUP BY dd.driverId, dd.driver_name
HAVING COUNT(*) >= 20  
ORDER BY avg_positions_gained DESC
LIMIT 10;

-- Drivers who outperformed teammates most often
WITH recent_races AS(
SELECT raceId,year FROM races
WHERE year BETWEEN 2019 AND 2024
),
teammate_duels AS(
SELECT 
r1.driverId as driver,
r2.driverId AS teammate,
r1.raceId,
r1.constructorId,
r1.positionOrder as driver_pos,
r2.positionOrder as teammate_pos
FROM results r1
JOIN results r2
ON r1.raceId=r2.raceId
AND r1.constructorId=r2.constructorId
AND r1.driverId <> r2.driverId
JOIN recent_races rr ON r1.raceId=rr.raceId
WHERE r1.positionOrder>0 AND r2.positionOrder>0
),

duel_wins AS(
SELECT 
driver,
COUNT(*) AS times_beaten_teammate
FROM teammate_duels
WHERE driver_pos<teammate_pos
GROUP BY driver
)

SELECT 
dd.driver_name,
dw.times_beaten_teammate
FROM duel_wins dw
JOIN driver_Details dd ON dw.driver=dd.driverId
ORDER BY dw.times_beaten_teammate DESC



-- race with most retirements
SELECT r.raceId,
ra.year,
ra.name AS race_name,
COUNT(*) AS num_retirements
FROM results r
JOIN status s on r.statusId=s.statusId
JOIN races ra on r.raceId=ra.raceId
WHERE r.statusId>1
GROUP BY ra.raceId,ra.year,ra.name
ORDER BY num_retirements DESC
LIMIT 3;

-- Races with most overtakes (grid vs final positions)
SELECT ra.raceId,
ra.year,
ra.name AS race_name,
SUM(r.grid-r.positionOrder) AS total_overtakes
FROM results r
JOIN races ra on r.raceId=ra.raceId
where r.grid>0 and r.positionOrder>0
group by ra.raceId,RA.YEAR,RA.NAME
order by total_overtakes desc
LIMIT 10;

-- Circuits with highest crash/retire rate
WITH dnf_statuses AS (
  SELECT statusId
  FROM status
  WHERE status LIKE '%accident%'
     OR status LIKE '%retired%'
     OR status LIKE '%engine%'
     OR status LIKE '%disqualified%'
     OR status LIKE '%gearbox%'
     OR status LIKE '%suspension%'
     OR status LIKE '%did not finish%'
),

circuit_dnf_stats AS (
  SELECT
    ci.circuitId,
    ci.name AS circuit_name,
    COUNT(r.resultId) AS total_results,
    SUM(CASE WHEN r.statusId IN (SELECT statusId FROM dnf_statuses) THEN 1 ELSE 0 END) AS total_dnfs
  FROM results r
  JOIN races ra ON r.raceId = ra.raceId
  JOIN circuits ci ON ra.circuitId = ci.circuitId
  GROUP BY ci.circuitId, ci.name
)

SELECT
  circuit_name,
  total_results,
  total_dnfs,
  ROUND(100.0 * total_dnfs / total_results, 2) AS dnf_percentage
FROM circuit_dnf_stats
WHERE total_results > 50 -- filter to circuits with sufficient data
ORDER BY dnf_percentage DESC
LIMIT 10;

-- Who performed best in specific circuits (e.g., Spa, Monaco)
WITH driver_details AS (
  SELECT driverId, CONCAT(forename, ' ', surname) AS driver_name
  FROM drivers
),

filtered_races AS (
  SELECT raceId, circuitId, year
  FROM races
  WHERE circuitId IN (
    SELECT circuitId FROM circuits WHERE name = 'Circuit de Monaco'  -- Replace '?' with the circuit name you want
  )
),

driver_performance AS (
  SELECT
    r.driverId,
    dd.driver_name,
    fr.circuitId,
    c.name AS circuit_name,
    SUM(r.points) AS total_points,
    COUNT(CASE WHEN r.positionOrder = 1 THEN 1 END) AS wins,
    COUNT(CASE WHEN r.positionOrder <= 3 THEN 1 END) AS podiums,
    AVG(r.positionOrder) AS avg_finish_position,
    COUNT(*) AS total_races
  FROM results r
  JOIN filtered_races fr ON r.raceId = fr.raceId
  JOIN circuits c ON fr.circuitId = c.circuitId
  JOIN driver_details dd ON r.driverId = dd.driverId
  GROUP BY r.driverId, dd.driver_name, fr.circuitId, c.name
)

SELECT 
  driver_name,
  circuit_name,
  total_points,
  wins,
  podiums,
  ROUND(avg_finish_position, 2) AS avg_finish_position,
  total_races
FROM driver_performance
ORDER BY total_points DESC;


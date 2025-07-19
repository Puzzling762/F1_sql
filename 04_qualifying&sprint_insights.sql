--  Drivers Who Gained vs Lost Most Positions on Average
SELECT 
d.driverId,
CONCAT(d.forename,' ',d.surname) AS driver_name,
COUNT(*) AS total_races,
ROUND(AVG(CASE WHEN r.grid>0 THEN r.grid END), 2) AS avg_qualifying_pos,
ROUND(AVG(CASE WHEN r.positionOrder>0 THEN r.positionOrder END),2) AS avg_finish_position,
ROUND(AVG(r.positionOrder - r.grid), 2) AS avg_position_loss
FROM results r
JOIN drivers d on r.driverId=d.driverId
WHERE r.grid>0 and r.positionOrder>0
GROUP BY d.driverId,driver_name
HAVING total_races >= 30 AND avg_position_loss > 0
ORDER BY total_races DESC;

-- Sprint race winners vs final race winners
SELECT
ra.year,
ra.name AS race_name,
CONCAT(ds.forename,' ',ds.surname) AS sprint_winner,
cs.name AS sprint_team,
CONCAT(df.forename,' ',df.surname) AS race_Winner,
cf.name AS race_team,
CASE
	WHEN ds.driverId=df.driverId THEN 'Same'
    ELSE 'Different'
    END AS sprint_vs_race_Winner
FROM races ra
JOIN sprint_results sr ON ra.raceId=sr.raceId and sr.positionOrder=1
JOIN drivers ds ON sr.driverId = ds.driverId
JOIN constructors cs ON sr.constructorId = cs.constructorId

JOIN results r ON ra.raceId = r.raceId AND r.positionOrder = 1
JOIN drivers df ON r.driverId = df.driverId
JOIN constructors cf ON r.constructorId = cf.constructorId

WHERE ra.year>=2021
ORDER BY ra.year,ra.round



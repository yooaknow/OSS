CREATE DATABASE IF NOT EXISTS travel_rec;
USE travel_rec;

CREATE USER IF NOT EXISTS 'recuser'@'%' IDENTIFIED BY 'recpass';
GRANT ALL PRIVILEGES ON travel_rec.* TO 'recuser'@'%';
FLUSH PRIVILEGES;

CREATE TABLE IF NOT EXISTS recommendation_history (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    party_size   VARCHAR(20)  NOT NULL,
    duration     VARCHAR(20)  NOT NULL,
    activity     VARCHAR(30)  NOT NULL,
    budget       VARCHAR(20)  NOT NULL,
    season       VARCHAR(10)  NOT NULL,
    results_json JSON,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

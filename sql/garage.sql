-- เพิ่มฟิลด์ที่ใช้บ่อยใน ESX Garage/Impound
ALTER TABLE `owned_vehicles`
  ADD COLUMN `garage_id` VARCHAR(64) NULL,
  ADD COLUMN `impounded` TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN `impound_until` DATETIME NULL,
  ADD COLUMN `impound_fee` INT NOT NULL DEFAULT 0;

-- ดัชนีเร่งความเร็วการค้นหา
CREATE INDEX idx_owned_vehicles_plate ON `owned_vehicles` (`plate`);
CREATE INDEX idx_owned_vehicles_owner ON `owned_vehicles` (`owner`);
CREATE INDEX idx_owned_vehicles_garage ON `owned_vehicles` (`garage_id`);

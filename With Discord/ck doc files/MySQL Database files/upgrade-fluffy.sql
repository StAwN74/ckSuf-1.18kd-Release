/* Updrade for upgrading from flufflys SurfTimer to our z4lab-surftimer */

/* Fixing timer crash after upgrading to our time */ 
/* Prestrafe Message */

ALTER TABLE `ck_playeroptions2` 
ADD COLUMN `prestrafe` INT(11) NOT NULL DEFAULT '0' AFTER `module5s`;
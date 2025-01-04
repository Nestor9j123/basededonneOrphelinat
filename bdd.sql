-- Table de l'enfant   
CREATE TABLE Enfant (  
    enf_id SERIAL PRIMARY KEY NOT NULL,  
    enf_nom VARCHAR(50) NOT NULL,  
    enf_prenom VARCHAR(50) NOT NULL,  
    date_entree_orphelinat DATE,  
    enf_dob DATE NOT NULL,  
    enf_med_hist TEXT,  
    enf_tuteur_id INT NOT NULL,  
    enf_scole_res VARCHAR(50),  
    enf_chambre INT,  
    sexe ENUM('Masculin', 'Féminin'),  
    
    FOREIGN KEY (enf_tuteur_id) REFERENCES Personnel(Per_id),  
    FOREIGN KEY (enf_chambre) REFERENCES Hebergement(id_chambre)  
);  

-- Table du personnel   
CREATE TABLE Personnel (  
    Per_id SERIAL PRIMARY KEY,  
    Per_nom VARCHAR(50) NOT NULL,  
    Per_prenom VARCHAR(50) NOT NULL,  
    Per_post VARCHAR(50) NOT NULL,  
    per_salaire DECIMAL(8,2),  
    per_horaire VARCHAR(100),  
    date_dembauche DATE NOT NULL,  
    max_enfants INT DEFAULT 5  -- Ajout de la colonne pour le maximum d'enfants  
);  

-- Table des dons  
CREATE TABLE Don (  
    don_id SERIAL PRIMARY KEY,  
    enf_id INT,  -- Ajout de la colonne enf_id pour référencer Enfant  
    don_auteur VARCHAR(50),  
    don_type ENUM('financière', 'matérielle') NOT NULL,  
    don_date DATE NOT NULL,  
    don_montant DECIMAL(10,2) NOT NULL,  
    don_dest VARCHAR(50),  
    FOREIGN KEY (enf_id) REFERENCES Enfant(enf_id)  
);  

-- Table des activités  
CREATE TABLE Activite (  
    act_id SERIAL PRIMARY KEY,  
    act_nom VARCHAR(50) NOT NULL,  
    act_date DATE NOT NULL,  
    act_montant DECIMAL(10,2)  -- Renommé pour plus de clarté  
);  

-- Table des ressources  
CREATE TABLE Ressource (  
    res_id SERIAL PRIMARY KEY,  
    res_type VARCHAR(20) NOT NULL,  
    res_quantite INT NOT NULL  
);  

-- Table du budget  
CREATE TABLE Budget (  
    Bud_id SERIAL PRIMARY KEY,  
    Bud_entree DECIMAL(10,2) NOT NULL,  
    Bud_depens DECIMAL(10,2) NOT NULL,  
    Bud_sold DECIMAL(10,2) NOT NULL  
);  

-- Table des adoptions  
CREATE TABLE Adoption (  
    id_Adoption SERIAL PRIMARY KEY,  
    nom_parain VARCHAR(50),  
    nom_maraine VARCHAR(50),  
    email_parain VARCHAR(50) UNIQUE,  
    email_maraine VARCHAR(50) UNIQUE,  
    enf_adopte_id INT,  
    FOREIGN KEY (enf_adopte_id) REFERENCES Enfant(enf_id)  
);  

-- Table de l'historique des dons   
CREATE TABLE Historique_don (  
    id_historique SERIAL PRIMARY KEY,  
    don_id INT,  
    don_type VARCHAR(20) NOT NULL,  
    don_date DATE NOT NULL,  
    don_montant DECIMAL(10,2),  
    FOREIGN KEY (don_id) REFERENCES Don(don_id)  
);  

-- Table des archives   
-- Table des archives pour enregistrer les actions  
CREATE TABLE Archives (  
    id_archive SERIAL PRIMARY KEY,  
    action_type ENUM('Adoption', 'Enregistrement Enfant', 'Enregistrement Employé', 'Ajout Activité') NOT NULL,  
    entity_id INT NOT NULL,  -- L'identifiant de l'entité concernée (enfant, employé, activité)  
    description TEXT,  
    date_action TIMESTAMP DEFAULT CURRENT_TIMESTAMP,  -- Timestamp par défaut à l'heure actuelle  
    FOREIGN KEY (entity_id) REFERENCES (SELECT enf_id FROM Enfant UNION SELECT Per_id FROM Personnel UNION SELECT act_id FROM Activite)  -- Note : Cette méthode n'est pas directement supportée par PostgreSQL, mais indique que chaque action se réfère à une entité basée sur le type d'action. Il faudra donc gérer les clés étrangères différemment dans le code d'application ou par un mécanisme de validation.  
); 

-- Table d'hébergement   
CREATE TABLE Hebergement (  
    id_chambre SERIAL PRIMARY KEY  
);  

-- Table pour stocker les variables constantes   
CREATE TABLE variables_constantes (  
    nom_variable TEXT PRIMARY KEY,  
    variable_valeur TEXT  
);  

-- Création des vues pour la BDD  
CREATE VIEW enfant_adoption AS  
SELECT enf.*, a.nom_parain, a.nom_maraine  
FROM Enfant enf  
JOIN Adoption a ON enf.enf_id = a.enf_adopte_id;  

CREATE VIEW ressources_disponible AS  
SELECT res_type, SUM(res_quantite) AS total_quantite  
FROM Ressource  
GROUP BY res_type;  

CREATE VIEW don_par_type AS  
SELECT don_type, SUM(don_montant) AS total_montant  
FROM Don  
GROUP BY don_type;  

-- Fonction pour attribuer une chambre  
CREATE OR REPLACE FUNCTION attribuer_chambre()  
RETURNS TRIGGER AS $$  
DECLARE  
    chambre_disponible INT;  
BEGIN  
    -- Vérifier s'il y a une chambre disponible  
    SELECT id_chambre INTO chambre_disponible  
    FROM Hebergement  
    WHERE id_chambre NOT IN (SELECT enf_chambre FROM Enfant WHERE enf_chambre IS NOT NULL)  
    LIMIT 1;  
     
    IF chambre_disponible IS NULL THEN  
        RAISE EXCEPTION 'Aucune chambre disponible pour attribuer à l\'enfant';  
    ELSE  
        -- Attribuer la chambre à l'enfant  
        NEW.enf_chambre := chambre_disponible;  
    END IF;  

    RETURN NEW;  
END;  
$$ LANGUAGE plpgsql;  

-- Fonction pour mettre à jour le budget  
CREATE OR REPLACE FUNCTION mettre_a_jour_budget()   
RETURNS TRIGGER AS $$  
BEGIN  
    -- Ajouter le montant à l'entrée du budget  
    UPDATE Budget  
    SET Bud_entree = Bud_entree + NEW.don_montant,  
        Bud_sold = Bud_entree - Bud_depens  -- Mise à jour du solde  
    WHERE Bud_id = 1;  -- Assurez-vous d'utiliser le bon ID de budget  
    RETURN NEW;  
END;  
$$ LANGUAGE plpgsql;   

-- Fonction pour mettre à jour le budget des dépenses après l'insertion d'une activité  
CREATE OR REPLACE FUNCTION mettre_a_jour_budget_depenses()   
RETURNS TRIGGER AS $$  
BEGIN  
    -- Ajouter le montant de la dépense de l'activité au budget des dépenses  
    UPDATE Budget  
    SET Bud_depens = Bud_depens + NEW.act_montant  -- Assurez-vous que act_montant représente la dépense  
    WHERE Bud_id = 1;  -- Utilisez le bon ID de budget correspond à votre base de données  

    RETURN NEW;  
END;  
$$ LANGUAGE plpgsql;  

-- Trigger pour mettre à jour le budget après l'insertion d'une activité  
CREATE TRIGGER trigger_mise_a_jour_budget_depenses  
AFTER INSERT ON Activite  
FOR EACH ROW EXECUTE FUNCTION mettre_a_jour_budget_depenses();  

-- Trigger pour mettre à jour le budget des dons  
CREATE TRIGGER trigger_mise_a_jour_don_materiel  
AFTER INSERT ON Don  
FOR EACH ROW EXECUTE FUNCTION mettre_a_jour_budget();  

-- Fonction pour supprimer un enfant  
CREATE OR REPLACE FUNCTION supprimer_enfant()   
RETURNS TRIGGER AS $$  
BEGIN  
    -- Supprime l'enregistrement de l'enfant  
    DELETE FROM Enfant WHERE enf_id = OLD.enf_id;  
    RETURN NULL;  -- Retourner NULL après suppression  
END;  
$$ LANGUAGE plpgsql;  

-- Trigger pour supprimer un enfant lors de l'adoption  
CREATE TRIGGER trigger_supprimer_enfant  
AFTER UPDATE ON Enfant  
FOR EACH ROW  
WHEN (OLD.adoption_status IS DISTINCT FROM NEW.adoption_status AND NEW.adoption_status = 'adopté')  
EXECUTE FUNCTION supprimer_enfant();  

-- Fonction pour vérifier si un enfant peut être supprimé  
CREATE OR REPLACE FUNCTION peut_supprimer_enfant(personne_id INT)  
RETURNS BOOLEAN AS $$  
DECLARE  
    nb_enfants INT;  
BEGIN  
    -- Compter le nombre d'enfants supervisés  
    SELECT COUNT(*) INTO nb_enfants   
    FROM Enfant   
    WHERE enf_tuteur_id = personne_id;  

    -- Vérifier si le nombre d'enfants est inférieur à la limite  
    RETURN nb_enfants < (SELECT max_enfants FROM Personnel WHERE Per_id = personne_id);  
END;  
$$ LANGUAGE plpgsql;  

-- Fonction pour trouver un tuteur disponible  
CREATE OR REPLACE FUNCTION trouver_tuteur_disponible()  
RETURNS INT AS $$  
DECLARE  
    tuteur_id INT;  
BEGIN  
    -- Trouve un tuteur qui n'a pas atteint sa limite  
    SELECT p.Per_id INTO tuteur_id   
    FROM Personnel p  
    WHERE (SELECT COUNT(*)  
           FROM Enfant e  
           WHERE e.enf_tuteur_id = p.Per_id) < p.max_enfants  
    LIMIT 1;  -- Prendre seulement un tuteur disponible  

    RETURN tuteur_id;  
END;  
$$ LANGUAGE plpgsql;  

-- Fonction pour assigner un tuteur à un enfant  
CREATE OR REPLACE FUNCTION assigner_tuteur()   
RETURNS TRIGGER AS $$  
DECLARE  
    tuteur_id INT;  
BEGIN  
    -- Trouver un tuteur disponible  
    tuteur_id := trouver_tuteur_disponible();  

    -- Vérifier si un tuteur a été trouvé  
    IF tuteur_id IS NULL THEN  
        RAISE EXCEPTION 'Aucun tuteur disponible pour cet enfant.';  
    END IF;  

    -- Assigner le tuteur trouvé à l'enfant  
    NEW.enf_tuteur_id := tuteur_id;  

    RETURN NEW;  -- Retourner la nouvelle ligne d'enfant avec le tuteur assigné  
END;  
$$ LANGUAGE plpgsql;  

-- Trigger pour assigner un tuteur avant l'insertion d'un enfant  
CREATE TRIGGER trigger_assigner_tuteur  
BEFORE INSERT ON Enfant  
FOR EACH ROW EXECUTE FUNCTION assigner_tuteur();  

-- Création d'index   
-- Index sur la colonne enf_tuteur_id de la table Enfant  
CREATE INDEX idx_enfant_tuteur ON Enfant(enf_tuteur_id);  

-- Index sur la colonne max_enfants de la table Personnel pour optimiser les requêtes de tuteur  
CREATE INDEX idx_personnel_max_enfants ON Personnel(max_enfants);  

-- Index sur la colonne enf_chambre de la table Enfant pour optimiser les requêtes d'attribution de chambre  
CREATE INDEX idx_enfant_chambre ON Enfant(enf_chambre);  

-- Index sur la colonne act_date de la table Activite pour optimiser les requêtes de filtrage de date  
CREATE INDEX idx_activite_date ON Activite(act_date);  

-- Index sur la colonne don_type de la table Don pour optimiser les requêtes par type de don  
CREATE INDEX idx_don_type ON Don(don_type);  

-- Fonction pour sauvegarder les données  
CREATE OR REPLACE PROCEDURE sauvegarder_donnees() LANGUAGE plpgsql AS $$  
BEGIN  
    -- Supprimer les anciennes sauvegardes si elles existent  
    DROP TABLE IF EXISTS Enfant_backup;  
    DROP TABLE IF EXISTS Personnel_backup;  
    DROP TABLE IF EXISTS Don_backup;  

    -- Sauvegarder la table Enfant dans une table temporaire  
    CREATE TABLE Enfant_backup AS   
    SELECT * FROM Enfant;  
    
    -- Sauvegarder la table Personnel dans une table temporaire  
    CREATE TABLE Personnel_backup AS   
    SELECT * FROM Personnel;  

    -- Sauvegarder la table Don dans une table temporaire  
    CREATE TABLE Don_backup AS   
    SELECT * FROM Don;  

    -- On peut ajouter d'autres sauvegardes selon les besoins  
END;  
$$;  
-- Ajouter l'enregistrement dans les archives lors d'une adoption  
CREATE OR REPLACE FUNCTION enregistrer_adoption()  
RETURNS TRIGGER AS $$  
BEGIN  
    INSERT INTO Archives (action_type, entity_id, description)  
    VALUES ('Adoption', NEW.enf_adopte_id, "Adoption enregistrée pour l\'enfant avec ID: " || NEW.enf_adopte_id);  

    RETURN NEW;  
END;  
$$ LANGUAGE plpgsql;  

-- Création du trigger pour l'enregistrement d'adoption  
CREATE TRIGGER trigger_enregistrer_adoption  
AFTER INSERT ON Adoption  
FOR EACH ROW EXECUTE FUNCTION enregistrer_adoption();

CREATE OR REPLACE FUNCTION enregistrer_enfant()  
RETURNS TRIGGER AS $$  
BEGIN  
    INSERT INTO Archives (action_type, entity_id, description)  
    VALUES ('Enregistrement Enfant', NEW.enf_id, 'Enfant enregistré avec ID: ' || NEW.enf_id);  

    RETURN NEW;  
END;  
$$ LANGUAGE plpgsql;  

CREATE TRIGGER trigger_enregistrer_enfant  
AFTER INSERT ON Enfant  
FOR EACH ROW EXECUTE FUNCTION enregistrer_enfant();

CREATE OR REPLACE FUNCTION enregistrer_employe()  
RETURNS TRIGGER AS $$  
BEGIN  
    INSERT INTO Archives (action_type, entity_id, description)  
    VALUES ('Enregistrement Employé', NEW.Per_id, 'Nouvel employé enregistré avec ID: ' || NEW.Per_id);  

    RETURN NEW;  
END;  
$$ LANGUAGE plpgsql;  

CREATE TRIGGER trigger_enregistrer_employe  
AFTER INSERT ON Personnel  
FOR EACH ROW EXECUTE FUNCTION enregistrer_employe();

CREATE OR REPLACE FUNCTION enregistrer_activite()  
RETURNS TRIGGER AS $$  
BEGIN  
    INSERT INTO Archives (action_type, entity_id, description)  
    VALUES ('Ajout Activité', NEW.act_id, 'Activité ajoutée avec ID: ' || NEW.act_id);  

    RETURN NEW;  
END;  
$$ LANGUAGE plpgsql;  

CREATE TRIGGER trigger_enregistrer_activite  
AFTER INSERT ON Activite  
FOR EACH ROW EXECUTE FUNCTION enregistrer_activite();



-- Pour appeler la procédure de sauvegarde, exécutez :  
CALL sauvegarder_donnees();
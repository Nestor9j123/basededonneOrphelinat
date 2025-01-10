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
    max_enfants INT DEFAULT 5
);

-- Table des dons
CREATE TABLE Don (
    don_id SERIAL PRIMARY KEY,
    enf_id INT,
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
    act_montant DECIMAL(10,2)
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

-- Table d'hébergement
CREATE TABLE Hebergement (
    id_chambre SERIAL PRIMARY KEY
);

-- Table pour stocker les variables constantes
CREATE TABLE variables_constantes (
    nom_variable TEXT PRIMARY KEY,
    variable_valeur TEXT
);

-- Table des archives pour les enfants
CREATE TABLE Archives_Enfants (
    id_archive SERIAL PRIMARY KEY,
    entity_id INT NOT NULL,
    description TEXT,
    date_action TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (entity_id) REFERENCES Enfant(enf_id)
);

-- Table des archives pour le personnel
CREATE TABLE Archives_Personnel (
    id_archive SERIAL PRIMARY KEY,
    entity_id INT NOT NULL,
    description TEXT,
    date_action TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (entity_id) REFERENCES Personnel(Per_id)
);

-- Table des archives pour les activités
CREATE TABLE Archives_Activites (
    id_archive SERIAL PRIMARY KEY,
    entity_id INT NOT NULL,
    description TEXT,
    date_action TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (entity_id) REFERENCES Activite(act_id)
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
    SELECT id_chambre INTO chambre_disponible
    FROM Hebergement
    WHERE id_chambre NOT IN (SELECT enf_chambre FROM Enfant WHERE enf_chambre IS NOT NULL)
    LIMIT 1;
     
    IF chambre_disponible IS NULL THEN
        RAISE EXCEPTION 'Aucune chambre disponible pour attribuer à l_enfant';
    ELSE
        NEW.enf_chambre := chambre_disponible;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour mettre à jour le budget
CREATE OR REPLACE FUNCTION mettre_a_jour_budget()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE Budget
    SET Bud_entree = Bud_entree + NEW.don_montant,
        Bud_sold = Bud_entree - Bud_depens
    WHERE Bud_id = 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour mettre à jour le budget des dépenses après l'insertion d'une activité
CREATE OR REPLACE FUNCTION mettre_a_jour_budget_depenses()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE Budget
    SET Bud_depens = Bud_depens + NEW.act_montant
    WHERE Bud_id = 1;
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
END;
$$;

-- Fonction pour enregistrer une action dans les archives des enfants
CREATE OR REPLACE FUNCTION enregistrer_enfant()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO Archives_Enfants (entity_id, description)
    VALUES (NEW.enf_id, 'Enfant enregistré avec ID: ' || NEW.enf_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_enregistrer_enfant
AFTER INSERT ON Enfant
FOR EACH ROW EXECUTE FUNCTION enregistrer_enfant();

-- Fonction pour enregistrer une action dans les archives du personnel
CREATE OR REPLACE FUNCTION enregistrer_employe()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO Archives_Personnel (entity_id, description)
    VALUES (NEW.Per_id, 'Nouvel employé enregistré avec ID: ' || NEW.Per_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_enregistrer_employe
AFTER INSERT ON Personnel
FOR EACH ROW EXECUTE FUNCTION enregistrer_employe();

-- Fonction pour enregistrer une action dans les archives des activités
CREATE OR REPLACE FUNCTION enregistrer_activite()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO Archives_Activites (entity_id, description)
    VALUES (NEW.act_id, 'Activité ajoutée avec ID: ' || NEW.act_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_enregistrer_activite
AFTER INSERT ON Activite
FOR EACH ROW EXECUTE FUNCTION enregistrer_activite();

-- Pour appeler la procédure de sauvegarde, exécutez :
CALL sauvegarder_donnees();

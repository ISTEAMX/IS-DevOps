INSERT INTO users (id, email, first_name, last_name, password, role) 
VALUES (
   1,
    'stasacflavius@unisync.ro', 
    'Stasac', 
    'Flavius', 
    '$2a$12$EgVefcmbXbIEcp03kWhodezo16N26TdDrfl.a4BaSxrpDHId/UpwO', 
    'ADMIN'
)
ON CONFLICT (id) DO NOTHING;

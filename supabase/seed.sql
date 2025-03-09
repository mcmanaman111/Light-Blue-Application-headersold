/*
  Seed Data for NCLEX Prep Database
  
  This file contains initial data for:
  - Topics (NCLEX Client Needs categories)
  - Subtopics (specific content areas within each category)
  
  This creates a foundation for categorizing questions and organizing study materials.
*/

-- Insert Topics (Client Needs Categories)
INSERT INTO topics (name, description) VALUES
('Management of Care', 'Focuses on coordination of care, safety, legal rights and ethical practice. (17-23% of NCLEX exam)'),
('Safety and Infection Control', 'Covers prevention of injury, emergency response and infection prevention. (9-15% of NCLEX exam)'),
('Health Promotion and Maintenance', 'Addresses prevention, early detection and lifestyle choices. (6-12% of NCLEX exam)'),
('Psychosocial Integrity', 'Deals with mental health, coping and cultural aspects of care. (6-12% of NCLEX exam)'),
('Basic Care and Comfort', 'Covers activities of daily living, nutrition and rest. (6-12% of NCLEX exam)'),
('Pharmacological Therapies', 'Focuses on medication administration and pain management. (12-18% of NCLEX exam)'),
('Reduction of Risk Potential', 'Addresses complications and health alterations. (9-15% of NCLEX exam)'),
('Physiological Adaptation', 'Covers care for acute, chronic and life-threatening conditions. (11-17% of NCLEX exam)');

-- Insert Subtopics

-- Management of Care subtopics
INSERT INTO subtopics (topic_id, name, description) VALUES
((SELECT id FROM topics WHERE name = 'Management of Care'), 'Assignment and delegation', 'Determining appropriate tasks for various healthcare team members'),
((SELECT id FROM topics WHERE name = 'Management of Care'), 'Legal rights and responsibilities', 'Understanding patient rights and nursing legal obligations'),
((SELECT id FROM topics WHERE name = 'Management of Care'), 'Ethics and advocacy', 'Applying ethical principles and advocating for patients'),
((SELECT id FROM topics WHERE name = 'Management of Care'), 'Case management', 'Coordinating care across multiple providers and settings'),
((SELECT id FROM topics WHERE name = 'Management of Care'), 'Quality improvement', 'Evaluating and improving care delivery systems');

-- Safety and Infection Control subtopics
INSERT INTO subtopics (topic_id, name, description) VALUES
((SELECT id FROM topics WHERE name = 'Safety and Infection Control'), 'Standard precautions', 'Universal measures to prevent infection transmission'),
((SELECT id FROM topics WHERE name = 'Safety and Infection Control'), 'Emergency response plans', 'Protocols for responding to emergency situations'),
((SELECT id FROM topics WHERE name = 'Safety and Infection Control'), 'Error prevention', 'Practices to prevent medication errors and other adverse events'),
((SELECT id FROM topics WHERE name = 'Safety and Infection Control'), 'Safe handling of materials', 'Proper techniques for handling hazardous and non-hazardous materials'),
((SELECT id FROM topics WHERE name = 'Safety and Infection Control'), 'Use of restraints', 'Appropriate and safe use of physical and chemical restraints');

-- Health Promotion and Maintenance subtopics
INSERT INTO subtopics (topic_id, name, description) VALUES
((SELECT id FROM topics WHERE name = 'Health Promotion and Maintenance'), 'Health screening', 'Assessments to detect health problems early'),
((SELECT id FROM topics WHERE name = 'Health Promotion and Maintenance'), 'Disease prevention', 'Strategies to prevent disease development'),
((SELECT id FROM topics WHERE name = 'Health Promotion and Maintenance'), 'Lifestyle choices', 'Education on healthy behaviors and choices'),
((SELECT id FROM topics WHERE name = 'Health Promotion and Maintenance'), 'Growth and development', 'Understanding normal development across the lifespan'),
((SELECT id FROM topics WHERE name = 'Health Promotion and Maintenance'), 'Self-care', 'Teaching patients to manage their own health needs');

-- Psychosocial Integrity subtopics
INSERT INTO subtopics (topic_id, name, description) VALUES
((SELECT id FROM topics WHERE name = 'Psychosocial Integrity'), 'Coping mechanisms', 'Strategies to help patients deal with stress and illness'),
((SELECT id FROM topics WHERE name = 'Psychosocial Integrity'), 'Mental health concepts', 'Understanding various mental health conditions and treatments'),
((SELECT id FROM topics WHERE name = 'Psychosocial Integrity'), 'Crisis intervention', 'Techniques for helping patients in acute psychological distress'),
((SELECT id FROM topics WHERE name = 'Psychosocial Integrity'), 'Cultural awareness', 'Providing care that respects cultural diversity'),
((SELECT id FROM topics WHERE name = 'Psychosocial Integrity'), 'End of life care', 'Supporting patients and families during end of life');

-- Basic Care and Comfort subtopics
INSERT INTO subtopics (topic_id, name, description) VALUES
((SELECT id FROM topics WHERE name = 'Basic Care and Comfort'), 'Personal hygiene', 'Assisting with and teaching personal hygiene tasks'),
((SELECT id FROM topics WHERE name = 'Basic Care and Comfort'), 'Mobility', 'Maintaining and improving functional mobility'),
((SELECT id FROM topics WHERE name = 'Basic Care and Comfort'), 'Nutrition and hydration', 'Meeting nutritional and fluid needs'),
((SELECT id FROM topics WHERE name = 'Basic Care and Comfort'), 'Sleep and rest', 'Promoting adequate rest and managing sleep disorders'),
((SELECT id FROM topics WHERE name = 'Basic Care and Comfort'), 'Elimination', 'Managing urinary and bowel elimination needs');

-- Pharmacological Therapies subtopics
INSERT INTO subtopics (topic_id, name, description) VALUES
((SELECT id FROM topics WHERE name = 'Pharmacological Therapies'), 'Medication administration', 'Safe preparation and administration of medicines'),
((SELECT id FROM topics WHERE name = 'Pharmacological Therapies'), 'Pain management', 'Pharmacological approaches to pain control'),
((SELECT id FROM topics WHERE name = 'Pharmacological Therapies'), 'Blood products', 'Administration and monitoring of blood components'),
((SELECT id FROM topics WHERE name = 'Pharmacological Therapies'), 'Parenteral therapies', 'Administration of medications via non-oral routes'),
((SELECT id FROM topics WHERE name = 'Pharmacological Therapies'), 'Medication calculations', 'Computing correct dosages for medication administration');

-- Reduction of Risk Potential subtopics
INSERT INTO subtopics (topic_id, name, description) VALUES
((SELECT id FROM topics WHERE name = 'Reduction of Risk Potential'), 'Diagnostic tests', 'Preparation and care related to diagnostic procedures'),
((SELECT id FROM topics WHERE name = 'Reduction of Risk Potential'), 'Lab values', 'Interpretation of laboratory test results'),
((SELECT id FROM topics WHERE name = 'Reduction of Risk Potential'), 'System assessments', 'Body system-specific assessment techniques'),
((SELECT id FROM topics WHERE name = 'Reduction of Risk Potential'), 'Potential complications', 'Identification and prevention of potential problems'),
((SELECT id FROM topics WHERE name = 'Reduction of Risk Potential'), 'Vital signs', 'Monitoring and interpreting vital sign changes');

-- Physiological Adaptation subtopics
INSERT INTO subtopics (topic_id, name, description) VALUES
((SELECT id FROM topics WHERE name = 'Physiological Adaptation'), 'Fluid/electrolyte balance', 'Managing alterations in fluid and electrolyte status'),
((SELECT id FROM topics WHERE name = 'Physiological Adaptation'), 'Medical emergencies', 'Responding to acute life-threatening situations'),
((SELECT id FROM topics WHERE name = 'Physiological Adaptation'), 'Pathophysiology', 'Understanding disease processes and manifestations'),
((SELECT id FROM topics WHERE name = 'Physiological Adaptation'), 'Unexpected responses', 'Managing unusual or adverse patient reactions'),
((SELECT id FROM topics WHERE name = 'Physiological Adaptation'), 'Hemodynamics', 'Monitoring and managing cardiac output and tissue perfusion');

-- Insert a sample admin user (if it doesn't exist)
-- Note: In a production environment, create admins through Supabase Authentication UI
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM auth.users 
        WHERE raw_user_meta_data->>'role' = 'admin'
    ) THEN
        -- This is just a placeholder. In reality, you'd create the admin user through Supabase Auth
        RAISE NOTICE 'No admin user exists. Create one through Supabase Authentication.';
    END IF;
END
$$;

-- Initialize CAT difficulty parameters for questions (if any exist)
-- This would normally happen after questions are added
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM questions LIMIT 1
    ) THEN
        PERFORM initialize_cat_parameters();
    END IF;
END
$$;

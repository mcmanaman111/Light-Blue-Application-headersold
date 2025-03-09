# NCLEX Prep Application - Supabase Database Implementation Plan

This document outlines the complete database structure for our NCLEX prep application, including tables, columns, relationships, and implementation steps.

## Implementation Strategy Overview

We'll build the database in the following phases:

1. **Core Question Bank Structure**
   - Topics, subtopics, questions, and answers
   - Question tracking system

2. **Test Management System**
   - Tests, test questions, and test results
   - User responses and scoring

3. **User Progress Tracking**
   - User profiles and statistics
   - Study plans and progress tracking

4. **CAT Implementation**
   - Ability estimation
   - Adaptive question selection

5. **Flashcards System**
   - User-created flashcards with spaced repetition

6. **Supporting Features**
   - Notes system
   - Feedback system
   - Notifications

## Phase 1: Core Question Bank Structure

### Table: topics

```json
{
  "name": "topics",
  "description": "Main nursing topics covered in the NCLEX exam",
  "columns": [
    { 
      "name": "id", 
      "type": "serial", 
      "primaryKey": true,
      "description": "Unique identifier for the topic"
    },
    { 
      "name": "name", 
      "type": "varchar(255)", 
      "nullable": false,
      "description": "Name of the topic (e.g., 'Management of Care', 'Pharmacology')"
    },
    { 
      "name": "description", 
      "type": "text",
      "description": "Detailed description of what the topic covers"
    },
    { 
      "name": "created_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When the topic was created"
    },
    { 
      "name": "updated_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When the topic was last updated"
    }
  ]
}
```

### Table: subtopics

```json
{
  "name": "subtopics",
  "description": "Specific nursing subtopics within each main topic",
  "columns": [
    { 
      "name": "id", 
      "type": "serial", 
      "primaryKey": true,
      "description": "Unique identifier for the subtopic"
    },
    { 
      "name": "topic_id", 
      "type": "integer", 
      "foreignKey": { "table": "topics", "column": "id" },
      "description": "Reference to the parent topic"
    },
    { 
      "name": "name", 
      "type": "varchar(255)", 
      "nullable": false,
      "description": "Name of the subtopic (e.g., 'Referrals', 'Delegation')"
    },
    { 
      "name": "description", 
      "type": "text",
      "description": "Detailed description of what the subtopic covers"
    },
    { 
      "name": "created_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When the subtopic was created"
    },
    { 
      "name": "updated_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When the subtopic was last updated"
    }
  ]
}
```

### Table: questions

```json
{
  "name": "questions",
  "description": "NCLEX-style questions for practice and exams",
  "columns": [
    { 
      "name": "id", 
      "type": "serial", 
      "primaryKey": true,
      "description": "Unique identifier for the question"
    },
    { 
      "name": "topic", 
      "type": "varchar(255)", 
      "nullable": false,
      "description": "Main topic the question relates to"
    },
    { 
      "name": "sub_topic", 
      "type": "varchar(255)", 
      "nullable": false,
      "description": "Specific subtopic the question relates to"
    },
    { 
      "name": "question_format", 
      "type": "varchar(255)", 
      "nullable": false,
      "description": "Format of the question (Multiple Choice, SATA, Hot Spot, etc.)"
    },
    { 
      "name": "ngn", 
      "type": "boolean", 
      "default": false,
      "description": "Whether this is a Next Generation NCLEX (NGN) question"
    },
    { 
      "name": "difficulty", 
      "type": "varchar(50)", 
      "nullable": false,
      "description": "Difficulty level (Easy, Medium, Hard)"
    },
    { 
      "name": "question_text", 
      "type": "text", 
      "nullable": false,
      "description": "The actual question text"
    },
    { 
      "name": "explanation", 
      "type": "text",
      "description": "Explanation of the correct answer and rationales"
    },
    { 
      "name": "use_partial_scoring", 
      "type": "boolean", 
      "default": false,
      "description": "Whether partial credit is available (for SATA questions)"
    },
    { 
      "name": "created_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When the question was created"
    },
    { 
      "name": "updated_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When the question was last updated"
    }
  ]
}
```

### Table: answers

```json
{
  "name": "answers",
  "description": "Answer options for each question",
  "columns": [
    { 
      "name": "id", 
      "type": "serial", 
      "primaryKey": true,
      "description": "Unique identifier for the answer"
    },
    { 
      "name": "question_id", 
      "type": "integer", 
      "foreignKey": { "table": "questions", "column": "id" },
      "description": "Reference to the parent question"
    },
    { 
      "name": "option_number", 
      "type": "integer", 
      "nullable": false,
      "description": "Order number of this answer option (1, 2, 3, 4, etc.)"
    },
    { 
      "name": "answer_text", 
      "type": "text", 
      "nullable": false,
      "description": "Text of the answer option"
    },
    { 
      "name": "is_correct", 
      "type": "boolean", 
      "default": false,
      "description": "Whether this is a correct answer"
    },
    { 
      "name": "partial_credit", 
      "type": "numeric(3,2)", 
      "default": 0.00,
      "description": "Partial credit value (0.00-1.00) for SATA questions"
    },
    { 
      "name": "penalty_value", 
      "type": "numeric(3,2)", 
      "default": 0.00,
      "description": "Penalty for selecting wrong answers in SATA questions"
    },
    { 
      "name": "created_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When the answer was created"
    },
    { 
      "name": "updated_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When the answer was last updated"
    }
  ]
}
```

### Table: user_question_status

```json
{
  "name": "user_question_status",
  "description": "Tracks each user's interaction with each question",
  "columns": [
    { 
      "name": "id", 
      "type": "serial", 
      "primaryKey": true,
      "description": "Unique identifier for the status record"
    },
    { 
      "name": "user_id", 
      "type": "uuid", 
      "foreignKey": { "table": "auth.users", "column": "id" },
      "nullable": false,
      "description": "User this record belongs to"
    },
    { 
      "name": "question_id", 
      "type": "integer", 
      "foreignKey": { "table": "questions", "column": "id" },
      "nullable": false,
      "description": "Question being tracked"
    },
    { 
      "name": "status", 
      "type": "varchar(50)", 
      "default": "unseen",
      "description": "Current status (unseen, correct, incorrect, marked, skipped)"
    },
    { 
      "name": "attempt_count", 
      "type": "integer", 
      "default": 0,
      "description": "Number of times user has attempted this question"
    },
    { 
      "name": "last_seen_at", 
      "type": "timestamp with time zone",
      "description": "When the user last saw this question"
    },
    { 
      "name": "notes", 
      "type": "text",
      "description": "User's personal notes about this question"
    },
    { 
      "name": "created_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this record was created"
    },
    { 
      "name": "updated_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this record was last updated"
    }
  ]
}
```

## Phase 2: Test Management System

### Table: tests

```json
{
  "name": "tests",
  "description": "Test sessions created by users",
  "columns": [
    { 
      "name": "id", 
      "type": "serial", 
      "primaryKey": true,
      "description": "Unique identifier for the test"
    },
    { 
      "name": "user_id", 
      "type": "uuid", 
      "foreignKey": { "table": "auth.users", "column": "id" },
      "nullable": false,
      "description": "User who created the test"
    },
    { 
      "name": "title", 
      "type": "varchar(255)",
      "description": "Optional title for the test"
    },
    { 
      "name": "mode", 
      "type": "varchar(255)", 
      "description": "Test mode (Practice, Simulation, CAT, etc.)"
    },
    { 
      "name": "question_count", 
      "type": "integer",
      "description": "Number of questions in this test" 
    },
    { 
      "name": "topics", 
      "type": "varchar(255)[]",
      "description": "Array of topics included in this test" 
    },
    { 
      "name": "subtopics", 
      "type": "varchar(255)[]",
      "description": "Array of subtopics included in this test" 
    },
    { 
      "name": "difficulty", 
      "type": "varchar(50)",
      "description": "Test difficulty setting (Easy, Medium, Hard, Mixed)" 
    },
    { 
      "name": "time_limit_minutes", 
      "type": "integer",
      "description": "Time limit in minutes, if applicable" 
    },
    { 
      "name": "status", 
      "type": "varchar(50)", 
      "default": "in_progress",
      "description": "Test status (in_progress, completed, abandoned)" 
    },
    { 
      "name": "created_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When the test was created"
    },
    { 
      "name": "started_at", 
      "type": "timestamp with time zone",
      "description": "When the test was started"
    },
    { 
      "name": "finished_at", 
      "type": "timestamp with time zone",
      "description": "When the test was completed"
    }
  ]
}
```

### Table: test_questions

```json
{
  "name": "test_questions",
  "description": "Links questions to tests with order information",
  "columns": [
    { 
      "name": "id", 
      "type": "serial", 
      "primaryKey": true,
      "description": "Unique identifier for this test question record"
    },
    { 
      "name": "test_id", 
      "type": "integer", 
      "foreignKey": { "table": "tests", "column": "id" },
      "nullable": false,
      "description": "Test this question belongs to"
    },
    { 
      "name": "question_id", 
      "type": "integer", 
      "foreignKey": { "table": "questions", "column": "id" },
      "nullable": false,
      "description": "Question included in the test"
    },
    { 
      "name": "question_order", 
      "type": "integer", 
      "nullable": false,
      "description": "Order of this question in the test"
    },
    { 
      "name": "created_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this record was created"
    }
  ]
}
```

### Table: test_results

```json
{
  "name": "test_results",
  "description": "User responses to test questions and scores",
  "columns": [
    { 
      "name": "id", 
      "type": "serial", 
      "primaryKey": true,
      "description": "Unique identifier for this test result"
    },
    { 
      "name": "test_id", 
      "type": "integer", 
      "foreignKey": { "table": "tests", "column": "id" },
      "nullable": false,
      "description": "Test this result belongs to"
    },
    { 
      "name": "user_id", 
      "type": "uuid", 
      "foreignKey": { "table": "auth.users", "column": "id" },
      "nullable": false,
      "description": "User who took the test"
    },
    { 
      "name": "question_id", 
      "type": "integer", 
      "foreignKey": { "table": "questions", "column": "id" },
      "nullable": false,
      "description": "Question being answered"
    },
    { 
      "name": "user_response", 
      "type": "text[]",
      "description": "Array of answer IDs or texts selected by the user"
    },
    { 
      "name": "is_correct", 
      "type": "boolean",
      "description": "Whether the answer was correct"
    },
    { 
      "name": "score", 
      "type": "numeric(5,2)",
      "description": "Points earned for this question"
    },
    { 
      "name": "max_score", 
      "type": "numeric(5,2)",
      "description": "Maximum possible points for this question"
    },
    { 
      "name": "time_spent_seconds", 
      "type": "integer",
      "description": "Time spent on this question in seconds"
    },
    { 
      "name": "is_flagged", 
      "type": "boolean", 
      "default": false,
      "description": "Whether user flagged this question for review"
    },
    { 
      "name": "answered_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When the user answered this question"
    }
  ]
}
```

## Phase 3: User Progress Tracking

### Table: user_profiles

```json
{
  "name": "user_profiles",
  "description": "Extended information about users",
  "columns": [
    { 
      "name": "id", 
      "type": "serial", 
      "primaryKey": true,
      "description": "Unique identifier for this profile"
    },
    { 
      "name": "user_id", 
      "type": "uuid", 
      "foreignKey": { "table": "auth.users", "column": "id" },
      "nullable": false,
      "description": "User this profile belongs to"
    },
    { 
      "name": "first_name", 
      "type": "varchar(255)",
      "description": "User's first name"
    },
    { 
      "name": "last_name", 
      "type": "varchar(255)",
      "description": "User's last name"
    },
    { 
      "name": "nursing_program", 
      "type": "varchar(255)",
      "description": "User's nursing program type (BSN, ADN, etc.)"
    },
    { 
      "name": "graduation_date", 
      "type": "date",
      "description": "User's graduation date"
    },
    { 
      "name": "exam_date", 
      "type": "date",
      "description": "Scheduled NCLEX exam date"
    },
    { 
      "name": "avatar_url", 
      "type": "text",
      "description": "URL to user's avatar image"
    },
    { 
      "name": "created_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this profile was created"
    },
    { 
      "name": "updated_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this profile was last updated"
    }
  ]
}
```

### Table: user_statistics

```json
{
  "name": "user_statistics",
  "description": "Performance statistics for users by topic/subtopic",
  "columns": [
    { 
      "name": "id", 
      "type": "serial", 
      "primaryKey": true,
      "description": "Unique identifier for this statistics record"
    },
    { 
      "name": "user_id", 
      "type": "uuid", 
      "foreignKey": { "table": "auth.users", "column": "id" },
      "nullable": false,
      "description": "User these statistics belong to"
    },
    { 
      "name": "topic", 
      "type": "varchar(255)", 
      "nullable": false,
      "description": "Topic these statistics are for"
    },
    { 
      "name": "sub_topic", 
      "type": "varchar(255)",
      "description": "Subtopic these statistics are for (nullable for topic-level stats)"
    },
    { 
      "name": "correct_count", 
      "type": "integer", 
      "default": 0,
      "description": "Number of questions answered correctly"
    },
    { 
      "name": "total_count", 
      "type": "integer", 
      "default": 0,
      "description": "Total number of questions attempted"
    },
    { 
      "name": "average_time_seconds", 
      "type": "numeric(10,2)", 
      "default": 0,
      "description": "Average time spent per question in seconds"
    },
    { 
      "name": "created_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When these statistics were created"
    },
    { 
      "name": "updated_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When these statistics were last updated"
    }
  ]
}
```

### Table: study_plans

```json
{
  "name": "study_plans",
  "description": "Personalized study plans for users",
  "columns": [
    { 
      "name": "id", 
      "type": "serial", 
      "primaryKey": true,
      "description": "Unique identifier for this study plan"
    },
    { 
      "name": "user_id", 
      "type": "uuid", 
      "foreignKey": { "table": "auth.users", "column": "id" },
      "nullable": false,
      "description": "User this study plan belongs to"
    },
    { 
      "name": "title", 
      "type": "varchar(255)", 
      "nullable": false,
      "description": "Title of the study plan"
    },
    { 
      "name": "description", 
      "type": "text",
      "description": "Description of the study plan"
    },
    { 
      "name": "start_date", 
      "type": "date", 
      "nullable": false,
      "description": "Start date of the study plan"
    },
    { 
      "name": "end_date", 
      "type": "date", 
      "nullable": false,
      "description": "End date of the study plan (exam date)"
    },
    { 
      "name": "created_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this study plan was created"
    },
    { 
      "name": "updated_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this study plan was last updated"
    }
  ]
}
```

### Table: study_plan_items

```json
{
  "name": "study_plan_items",
  "description": "Individual tasks within a study plan",
  "columns": [
    { 
      "name": "id", 
      "type": "serial", 
      "primaryKey": true,
      "description": "Unique identifier for this study plan item"
    },
    { 
      "name": "study_plan_id", 
      "type": "integer", 
      "foreignKey": { "table": "study_plans", "column": "id" },
      "nullable": false,
      "description": "Study plan this item belongs to"
    },
    { 
      "name": "due_date", 
      "type": "date", 
      "nullable": false,
      "description": "Due date for this study task"
    },
    { 
      "name": "topic", 
      "type": "varchar(255)", 
      "nullable": false,
      "description": "Topic associated with this task"
    },
    { 
      "name": "sub_topic", 
      "type": "varchar(255)",
      "description": "Subtopic associated with this task (if applicable)"
    },
    { 
      "name": "activity_type", 
      "type": "varchar(255)", 
      "nullable": false,
      "description": "Type of activity (Study, Practice, Review, etc.)"
    },
    { 
      "name": "description", 
      "type": "text", 
      "nullable": false,
      "description": "Description of what the student should do"
    },
    { 
      "name": "duration_minutes", 
      "type": "integer", 
      "nullable": false,
      "description": "Estimated duration in minutes"
    },
    { 
      "name": "completed", 
      "type": "boolean", 
      "default": false,
      "description": "Whether the task has been completed"
    },
    { 
      "name": "completed_at", 
      "type": "timestamp with time zone",
      "description": "When the task was completed"
    },
    { 
      "name": "created_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this task was created"
    },
    { 
      "name": "updated_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this task was last updated"
    }
  ]
}
```

## Phase 4: CAT Implementation

### Table: cat_sessions

```json
{
  "name": "cat_sessions",
  "description": "Computer Adaptive Testing sessions",
  "columns": [
    { 
      "name": "id", 
      "type": "serial", 
      "primaryKey": true,
      "description": "Unique identifier for this CAT session"
    },
    { 
      "name": "test_id", 
      "type": "integer", 
      "foreignKey": { "table": "tests", "column": "id" },
      "nullable": false,
      "description": "Test associated with this CAT session"
    },
    { 
      "name": "user_id", 
      "type": "uuid", 
      "foreignKey": { "table": "auth.users", "column": "id" },
      "nullable": false,
      "description": "User taking this CAT test"
    },
    { 
      "name": "initial_ability", 
      "type": "numeric(5,2)", 
      "default": 0,
      "description": "Initial ability estimate for the user"
    },
    { 
      "name": "current_ability", 
      "type": "numeric(5,2)", 
      "default": 0,
      "description": "Current ability estimate for the user"
    },
    { 
      "name": "ability_confidence", 
      "type": "numeric(5,2)", 
      "default": 0,
      "description": "Confidence level in the ability estimate"
    },
    { 
      "name": "passing_standard", 
      "type": "numeric(5,2)", 
      "default": 0,
      "description": "Passing standard for this session"
    },
    { 
      "name": "min_questions", 
      "type": "integer", 
      "default": 75,
      "description": "Minimum number of questions"
    },
    { 
      "name": "max_questions", 
      "type": "integer", 
      "default": 145,
      "description": "Maximum number of questions"
    },
    { 
      "name": "questions_answered", 
      "type": "integer", 
      "default": 0,
      "description": "Number of questions answered so far"
    },
    { 
      "name": "status", 
      "type": "varchar(50)", 
      "default": "in_progress",
      "description": "Session status (in_progress, passed, failed, abandoned)"
    },
    { 
      "name": "created_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this session was created"
    },
    { 
      "name": "updated_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this session was last updated"
    }
  ]
}
```

### Table: question_difficulty_parameters

```json
{
  "name": "question_difficulty_parameters",
  "description": "Item Response Theory parameters for questions",
  "columns": [
    { 
      "name": "id", 
      "type": "serial", 
      "primaryKey": true,
      "description": "Unique identifier for this parameter set"
    },
    { 
      "name": "question_id", 
      "type": "integer", 
      "foreignKey": { "table": "questions", "column": "id" },
      "nullable": false,
      "description": "Question these parameters apply to"
    },
    { 
      "name": "discrimination", 
      "type": "numeric(5,2)", 
      "default": 1,
      "description": "Item discrimination parameter (a-parameter in IRT)"
    },
    { 
      "name": "difficulty", 
      "type": "numeric(5,2)", 
      "default": 0,
      "description": "Item difficulty parameter (b-parameter in IRT)"
    },
    { 
      "name": "guessing", 
      "type": "numeric(5,2)", 
      "default": 0,
      "description": "Guessing parameter (c-parameter in IRT)"
    },
    { 
      "name": "created_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When these parameters were created"
    },
    { 
      "name": "updated_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When these parameters were last updated"
    }
  ]
}
```

### Table: cat_question_selections

```json
{
  "name": "cat_question_selections",
  "description": "Log of questions selected by CAT algorithm",
  "columns": [
    { 
      "name": "id", 
      "type": "serial", 
      "primaryKey": true,
      "description": "Unique identifier for this selection record"
    },
    { 
      "name": "cat_session_id", 
      "type": "integer", 
      "foreignKey": { "table": "cat_sessions", "column": "id" },
      "nullable": false,
      "description": "CAT session this selection belongs to"
    },
    { 
      "name": "question_id", 
      "type": "integer", 
      "foreignKey": { "table": "questions", "column": "id" },
      "nullable": false,
      "description": "Question that was selected"
    },
    { 
      "name": "position", 
      "type": "integer", 
      "nullable": false,
      "description": "Position of this question in the sequence"
    },
    { 
      "name": "ability_estimate_before", 
      "type": "numeric(5,2)",
      "description": "Ability estimate before answering this question"
    },
    { 
      "name": "ability_estimate_after", 
      "type": "numeric(5,2)",
      "description": "Ability estimate after answering this question"
    },
    { 
      "name": "information_value", 
      "type": "numeric(5,2)",
      "description": "Information value of this question selection"
    },
    { 
      "name": "was_correct", 
      "type": "boolean",
      "description": "Whether the user answered correctly"
    },
    { 
      "name": "created_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this selection was made"
    }
  ]
}
```

## Phase 5: Flashcards System

### Table: flashcard_decks

```json
{
  "name": "flashcard_decks",
  "description": "Collections of flashcards created by users",
  "columns": [
    { 
      "name": "id", 
      "type": "serial", 
      "primaryKey": true,
      "description": "Unique identifier for this flashcard deck"
    },
    { 
      "name": "user_id", 
      "type": "uuid", 
      "foreignKey": { "table": "auth.users", "column": "id" },
      "nullable": false,
      "description": "User who created this deck"
    },
    { 
      "name": "title", 
      "type": "varchar(255)", 
      "nullable": false,
      "description": "Title of the flashcard deck"
    },
    { 
      "name": "description", 
      "type": "text",
      "description": "Description of the flashcard deck's contents"
    },
    { 
      "name": "topic", 
      "type": "varchar(255)",
      "description": "Main topic this deck covers"
    },
    { 
      "name": "sub_topic", 
      "type": "varchar(255)",
      "description": "Specific subtopic this deck covers"
    },
    { 
      "name": "is_public", 
      "type": "boolean", 
      "default": false,
      "description": "Whether this deck is shared publicly"
    },
    { 
      "name": "card_count", 
      "type": "integer", 
      "default": 0,
      "description": "Number of cards in this deck"
    },
    { 
      "name": "created_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this deck was created"
    },
    { 
      "name": "updated_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this deck was last updated"
    }
  ]
}
```

### Table: flashcards

```json
{
  "name": "flashcards",
  "description": "Individual flashcards for study",
  "columns": [
    { 
      "name": "id", 
      "type": "serial", 
      "primaryKey": true,
      "description": "Unique identifier for this flashcard"
    },
    { 
      "name": "deck_id", 
      "type": "integer", 
      "foreignKey": { "table": "flashcard_decks", "column": "id" },
      "nullable": false,
      "description": "Deck this flashcard belongs to"
    },
    { 
      "name": "front", 
      "type": "text", 
      "nullable": false,
      "description": "Front side content (question)"
    },
    { 
      "name": "back", 
      "type": "text", 
      "nullable": false,
      "description": "Back side content (answer)"
    },
    { 
      "name": "topic", 
      "type": "varchar(255)",
      "description": "Topic this flashcard covers"
    },
    { 
      "name": "sub_topic", 
      "type": "varchar(255)",
      "description": "Subtopic this flashcard covers"
    },
    { 
      "name": "created_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this flashcard was created"
    },
    { 
      "name": "updated_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this flashcard was last updated"
    }
  ]
}
```

### Table: flashcard_progress

```json
{
  "name": "flashcard_progress",
  "description": "Tracks user progress with individual flashcards",
  "columns": [
    { 
      "name": "id", 
      "type": "serial", 
      "primaryKey": true,
      "description": "Unique identifier for this progress record"
    },
    { 
      "name": "user_id", 
      "type": "uuid", 
      "foreignKey": { "table": "auth.users", "column": "id" },
      "nullable": false,
      "description": "User this progress belongs to"
    },
    { 
      "name": "flashcard_id", 
      "type": "integer", 
      "foreignKey": { "table": "flashcards", "column": "id" },
      "nullable": false,
      "description": "Flashcard being tracked"
    },
    { 
      "name": "ease_factor", 
      "type": "numeric(4,3)", 
      "default": 2.5,
      "description": "Ease factor for spaced repetition (typically 1.3-2.5)"
    },
    { 
      "name": "interval_days", 
      "type": "integer", 
      "default": 1,
      "description": "Current interval in days"
    },
    { 
      "name": "last_reviewed", 
      "type": "timestamp with time zone",
      "description": "When the card was last reviewed"
    },
    { 
      "name": "next_review", 
      "type": "timestamp with time zone",
      "description": "When the card should be reviewed next"
    },
    { 
      "name": "review_count", 
      "type": "integer", 
      "default": 0,
      "description": "How many times this card has been reviewed"
    },
    { 
      "name": "last_performance", 
      "type": "smallint",
      "description": "Last review performance (0-5 scale)"
    },
    { 
      "name": "created_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this progress record was created"
    },
    { 
      "name": "updated_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this progress record was last updated"
    }
  ]
}
```

## Phase 6: Supporting Features

### Table: notes

```json
{
  "name": "notes",
  "description": "User notes related to study materials and questions",
  "columns": [
    { 
      "name": "id", 
      "type": "uuid", 
      "primaryKey": true, 
      "default": "gen_random_uuid()",
      "description": "Unique identifier for this note"
    },
    { 
      "name": "user_id", 
      "type": "uuid", 
      "foreignKey": { "table": "auth.users", "column": "id" },
      "nullable": false,
      "description": "User who created this note"
    },
    { 
      "name": "content", 
      "type": "text", 
      "nullable": false,
      "description": "Content of the note"
    },
    { 
      "name": "question_id", 
      "type": "integer", 
      "foreignKey": { "table": "questions", "column": "id" },
      "description": "Question this note is related to (if applicable)"
    },
    { 
      "name": "test_id", 
      "type": "integer", 
      "foreignKey": { "table": "tests", "column": "id" },
      "description": "Test this note is related to (if applicable)"
    },
    { 
      "name": "topic", 
      "type": "varchar(255)",
      "description": "Topic this note relates to"
    },
    { 
      "name": "sub_topic", 
      "type": "varchar(255)",
      "description": "Subtopic this note relates to"
    },
    { 
      "name": "created_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this note was created"
    },
    { 
      "name": "updated_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this note was last updated"
    }
  ]
}
```

### Table: question_feedback

```json
{
  "name": "question_feedback",
  "description": "User feedback on questions",
  "columns": [
    { 
      "name": "id", 
      "type": "uuid", 
      "primaryKey": true, 
      "default": "gen_random_uuid()",
      "description": "Unique identifier for this feedback"
    },
    { 
      "name": "user_id", 
      "type": "uuid", 
      "foreignKey": { "table": "auth.users", "column": "id" },
      "nullable": false,
      "description": "User who submitted this feedback"
    },
    { 
      "name": "question_id", 
      "type": "integer", 
      "foreignKey": { "table": "questions", "column": "id" },
      "nullable": false,
      "description": "Question this feedback is about"
    },
    { 
      "name": "test_id", 
      "type": "integer", 
      "foreignKey": { "table": "tests", "column": "id" },
      "description": "Test where this feedback was given"
    },
    { 
      "name": "message", 
      "type": "text", 
      "nullable": false,
      "description": "Feedback message from the user"
    },
    { 
      "name": "rating", 
      "type": "integer", 
      "nullable": false,
      "description": "Rating given by the user (typically 1-5)"
    },
    { 
      "name": "difficulty", 
      "type": "varchar(50)", 
      "nullable": false,
      "description": "User's perception of question difficulty"
    },
    { 
      "name": "status", 
      "type": "varchar(50)", 
      "default": "pending",
      "description": "Status of this feedback (pending, reviewed, etc.)"
    },
    { 
      "name": "admin_response", 
      "type": "text",
      "description": "Response from an administrator"
    },
    { 
      "name": "created_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this feedback was created"
    },
    { 
      "name": "updated_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this feedback was last updated"
    }
  ]
}
```

### Table: notifications

```json
{
  "name": "notifications",
  "description": "System and user notifications",
  "columns": [
    { 
      "name": "id", 
      "type": "uuid", 
      "primaryKey": true, 
      "default": "gen_random_uuid()",
      "description": "Unique identifier for this notification"
    },
    { 
      "name": "user_id", 
      "type": "uuid", 
      "foreignKey": { "table": "auth.users", "column": "id" },
      "nullable": false,
      "description": "User this notification is for"
    },
    { 
      "name": "type", 
      "type": "varchar(255)", 
      "nullable": false,
      "description": "Type of notification (feedback, study, test, etc.)"
    },
    { 
      "name": "title", 
      "type": "varchar(255)", 
      "nullable": false,
      "description": "Title of the notification"
    },
    { 
      "name": "message", 
      "type": "text", 
      "nullable": false,
      "description": "Content of the notification"
    },
    { 
      "name": "link", 
      "type": "text",
      "description": "Optional link to include in the notification"
    },
    { 
      "name": "read", 
      "type": "boolean", 
      "default": false,
      "description": "Whether the notification has been read"
    },
    { 
      "name": "created_at", 
      "type": "timestamp with time zone", 
      "default": "now()",
      "description": "When this notification was created"
    }
  ]
}
```

## Implementation Steps

After creating a new Supabase project, we'll implement the database following these steps:

1. Create all tables in the proper order to maintain foreign key relationships
2. Implement RLS policies for all tables
3. Create functions and triggers for automated updates
4. Set up initial seed data for topics and subtopics
5. Create database views for common queries
6. Implement database functions for CAT algorithm

Each phase will be implemented in its own migration file for better organization and version control.

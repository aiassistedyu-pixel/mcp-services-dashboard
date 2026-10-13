# Study Guide: Database Systems Midterm

Shared study guide for CS 340 Database Systems. Contributors: Alex Chen, Joe Smith, Maria Lopez. Exam date: October 28, 2026.

## 1. Relational model

- A **relation** is a table; a **tuple** is a row; an **attribute** is a column.
- **Primary key:** uniquely identifies each row.
- **Foreign key:** references a primary key in another table and enforces referential integrity.

## 2. SQL essentials

- `SELECT`, `FROM`, `WHERE`, `GROUP BY`, `HAVING`, `ORDER BY`
- Joins: inner, left outer, right outer, full outer
- Aggregates: `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`
- Remember: `WHERE` filters rows before grouping; `HAVING` filters groups after.

## 3. Normalization

1. **1NF:** atomic values, no repeating groups
2. **2NF:** 1NF plus no partial dependency on a composite key
3. **3NF:** 2NF plus no transitive dependencies
4. **BCNF:** every determinant is a candidate key

## 4. Indexing

- B+ trees support range queries and are the default in most databases.
- Hash indexes are fast for equality lookups but cannot do ranges.
- Full-text indexes (like SQLite FTS5, which we use in Project Falcon) tokenize text for keyword search.

## 5. Transactions and ACID

- **Atomicity:** all or nothing
- **Consistency:** constraints hold before and after
- **Isolation:** concurrent transactions do not interfere
- **Durability:** committed data survives crashes

## Practice questions

1. Write a query that lists each student and the number of courses they are enrolled in, including students with zero courses.
2. Normalize a table with columns (StudentID, StudentName, CourseID, CourseName, Instructor) to 3NF.
3. Explain why a hash index would not help the query `WHERE age BETWEEN 18 AND 22`.

## Study plan

- [x] Review lecture slides 1–6 (Joe)
- [ ] Do practice exam from last year (everyone)
- [ ] Make flashcards for normal forms (Maria)
- [ ] Group review session Sunday at 2 PM in the library (Alex is booking the room)

const mysql = require('mysql');
const fs = require('fs');

// MySQL connection setup
const db = mysql.createConnection({
  host: '127.0.0.1',
  user: 'root',
  password: '',
  database: 'ams'
});

db.connect((err) => {
  if (err) {
    throw err;
  }
  console.log('MySQL connected...');

  // Read JSON structure
  const data = fs.readFileSync('tables.json');
  const tables = JSON.parse(data);

  // Function to drop and create tables
  const dropAndCreateTable = (table) => {
    return new Promise((resolve, reject) => {
      let dropSql = `DROP TABLE IF EXISTS ${table.tableName}`;
      db.query(dropSql, (err, result) => {
        if (err) return reject(err);
        console.log(`Table ${table.tableName} dropped`);

        let sql = `CREATE TABLE ${table.tableName} (`;
        const fieldDefinitions = table.fields.map((field) => {
          let fieldDef = `${field.fieldName} ${field.fieldType}`;
          if (field.notNull) fieldDef += ' NOT NULL';
          if (field.autoIncrement) fieldDef += ' AUTO_INCREMENT';
          if (field.primaryKey) fieldDef += ' PRIMARY KEY';
          if (field.default) fieldDef += ` DEFAULT ${field.default}`;
          return fieldDef;
        });

        sql += fieldDefinitions.join(', ');

        // Add foreign keys
        const foreignKeyDefinitions = table.fields.filter(field => field.foreignKey).map((field) => {
          return `FOREIGN KEY (${field.foreignKey.key}) REFERENCES ${field.foreignKey.references.table}(${field.foreignKey.references.field})`;
        });

        if (foreignKeyDefinitions.length > 0) {
          sql += ', ' + foreignKeyDefinitions.join(', ');
        }

        sql += ');';

        db.query(sql, (err, result) => {
          if (err) return reject(err);
          console.log(`Table ${table.tableName} created`);
          resolve();
        });
      });
    });
  };

  // Create tables asynchronously
  const createTables = async () => {
    for (const table of tables.tables) {
      await dropAndCreateTable(table);
    }
    db.end();
  };

  createTables().catch((err) => {
    console.error(err);
    db.end();
  });
});

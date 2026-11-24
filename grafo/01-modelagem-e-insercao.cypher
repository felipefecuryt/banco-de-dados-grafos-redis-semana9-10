// ============================================================================
// PARTE 1 - MODELAGEM E INSERCAO DE DADOS (Neo4j / Cypher)
// Sistema de recomendacao de um e-commerce
// ----------------------------------------------------------------------------
// Como executar:
//   cypher-shell -u neo4j -p senha123 -f grafo/01-modelagem-e-insercao.cypher
// ou colar o conteudo no Neo4j Browser (http://localhost:7474)
// ============================================================================


// ----------------------------------------------------------------------------
// 0. LIMPEZA DO BANCO (deixe comentado se nao quiser apagar dados existentes)
// ----------------------------------------------------------------------------
MATCH (n) DETACH DELETE n;


// ----------------------------------------------------------------------------
// 1. CONSTRAINTS E INDICES
// Garantem que nao existam dois nos com o mesmo id e aceleram o MATCH inicial
// de cada consulta (o ponto de entrada no grafo).
// ----------------------------------------------------------------------------
CREATE CONSTRAINT usuario_id_unico IF NOT EXISTS
FOR (u:Usuario) REQUIRE u.id IS UNIQUE;

CREATE CONSTRAINT produto_id_unico IF NOT EXISTS
FOR (p:Produto) REQUIRE p.id IS UNIQUE;

CREATE CONSTRAINT categoria_nome_unico IF NOT EXISTS
FOR (c:Categoria) REQUIRE c.nome IS UNIQUE;

CREATE INDEX produto_nome IF NOT EXISTS
FOR (p:Produto) ON (p.nome);


// ----------------------------------------------------------------------------
// 2. NOS DO TIPO :Usuario  (1o tipo de no obrigatorio)
// ----------------------------------------------------------------------------
CREATE (u1:Usuario  {id: 1, nome: 'Felipe',   email: 'felipe@email.com',   cidade: 'Sao Paulo',     data_cadastro: date('2025-01-15')})
CREATE (u2:Usuario  {id: 2, nome: 'Bruna',    email: 'bruna@email.com',    cidade: 'Sao Paulo',     data_cadastro: date('2025-02-03')})
CREATE (u3:Usuario  {id: 3, nome: 'Carlos',   email: 'carlos@email.com',   cidade: 'Campinas',      data_cadastro: date('2025-02-20')})
CREATE (u4:Usuario  {id: 4, nome: 'Daniela',  email: 'daniela@email.com',  cidade: 'Rio de Janeiro',data_cadastro: date('2025-03-11')})
CREATE (u5:Usuario  {id: 5, nome: 'Eduardo',  email: 'eduardo@email.com',  cidade: 'Sao Paulo',     data_cadastro: date('2025-03-28')})
CREATE (u6:Usuario  {id: 6, nome: 'Fernanda', email: 'fernanda@email.com', cidade: 'Curitiba',      data_cadastro: date('2025-04-05')})
CREATE (u7:Usuario  {id: 7, nome: 'Gabriel',  email: 'gabriel@email.com',  cidade: 'Belo Horizonte',data_cadastro: date('2025-04-19')})
CREATE (u8:Usuario  {id: 8, nome: 'Helena',   email: 'helena@email.com',   cidade: 'Salvador',      data_cadastro: date('2025-05-02')});


// ----------------------------------------------------------------------------
// 3. NOS DO TIPO :Produto  (2o tipo de no obrigatorio)
// ----------------------------------------------------------------------------
CREATE (:Produto {id: 101, nome: 'Notebook Gamer',    preco: 7499.90, estoque: 12, marca: 'Acer'})
CREATE (:Produto {id: 102, nome: 'Mouse Gamer RGB',   preco: 249.90,  estoque: 80, marca: 'Logitech'})
CREATE (:Produto {id: 103, nome: 'Teclado Mecanico',  preco: 459.90,  estoque: 45, marca: 'Redragon'})
CREATE (:Produto {id: 104, nome: 'Headset 7.1',       preco: 379.90,  estoque: 30, marca: 'HyperX'})
CREATE (:Produto {id: 105, nome: 'Monitor 144Hz',     preco: 1899.90, estoque: 18, marca: 'LG'})
CREATE (:Produto {id: 106, nome: 'Cadeira Gamer',     preco: 1299.00, estoque: 10, marca: 'ThunderX3'})
CREATE (:Produto {id: 107, nome: 'Smartphone 5G',     preco: 2799.00, estoque: 25, marca: 'Samsung'})
CREATE (:Produto {id: 108, nome: 'SSD NVMe 1TB',      preco: 549.90,  estoque: 60, marca: 'Kingston'});


// ----------------------------------------------------------------------------
// 4. NOS DO TIPO :Categoria  (3o tipo de no - extra, usado no desafio)
// ----------------------------------------------------------------------------
CREATE (:Categoria {nome: 'Informatica'})
CREATE (:Categoria {nome: 'Perifericos'})
CREATE (:Categoria {nome: 'Monitores'})
CREATE (:Categoria {nome: 'Mobiliario'})
CREATE (:Categoria {nome: 'Celulares'})
CREATE (:Categoria {nome: 'Armazenamento'});


// ----------------------------------------------------------------------------
// 5. RELACIONAMENTO :AMIGO_DE  (1a aresta obrigatoria)
// Usuario -> Usuario
//
// IMPORTANTE SOBRE A DIRECAO: amizade e uma relacao simetrica, mas no Cypher
// toda aresta e gravada com direcao. Por isso cada amizade e criada nos DOIS
// sentidos (A->B e B->A). Assim as consultas podem usar a seta sem perder
// resultados. A alternativa seria gravar em um sentido so e consultar com
// -[:AMIGO_DE]- (sem seta), que o Neo4j trata como "qualquer direcao".
// ----------------------------------------------------------------------------
MATCH (a:Usuario), (b:Usuario)
WHERE [a.id, b.id] IN [[1,2], [1,3], [2,4], [2,5], [3,5], [3,6], [4,7]]
CREATE (a)-[:AMIGO_DE {desde: date('2025-06-01')}]->(b),
       (b)-[:AMIGO_DE {desde: date('2025-06-01')}]->(a);

// Rede de amizades resultante:
//   Felipe(1)  -- Bruna(2), Carlos(3)
//   Bruna(2)   -- Felipe(1), Daniela(4), Eduardo(5)
//   Carlos(3)  -- Felipe(1), Eduardo(5), Fernanda(6)
//   Daniela(4) -- Bruna(2), Gabriel(7)
//   Helena(8)  -- sem amigos (serve de controle nas consultas)


// ----------------------------------------------------------------------------
// 6. RELACIONAMENTO :COMPROU  (2a aresta obrigatoria)
// Usuario -> Produto, com propriedades na propria aresta
// ----------------------------------------------------------------------------
MATCH (u:Usuario), (p:Produto)
WHERE [u.id, p.id] IN [
  [1,102], [1,103],                   // Felipe (usuario de referencia)
  [2,105],                            // Bruna     - amiga direta
  [3,101],                            // Carlos    - amigo direto, comprou o Notebook
  [4,101], [4,103], [4,104],          // Daniela   - amiga de amiga, comprou o Notebook
  [5,101], [5,102], [5,106],          // Eduardo   - amigo de amigo, comprou o Notebook
  [6,103], [6,105], [6,108],          // Fernanda  - amiga de amiga
  [7,101],                            // Gabriel   - 3o grau (nao deve aparecer)
  [8,101], [8,102], [8,103]           // Helena    - sem conexao (nao deve aparecer)
]
CREATE (u)-[:COMPROU {
  data: date('2025-09-10'),
  quantidade: 1,
  valor_pago: p.preco
}]->(p);

// Ajuste de uma compra com quantidade maior, so para mostrar a propriedade
MATCH (:Usuario {id: 4})-[c:COMPROU]->(:Produto {id: 104})
SET c.quantidade = 2, c.valor_pago = 759.80;


// ----------------------------------------------------------------------------
// 7. RELACIONAMENTO :PERTENCE_A  (3a aresta - extra, usada no desafio)
// Produto -> Categoria
// ----------------------------------------------------------------------------
MATCH (p:Produto), (c:Categoria)
WHERE (p.id = 101 AND c.nome = 'Informatica')
   OR (p.id IN [102, 103, 104] AND c.nome = 'Perifericos')
   OR (p.id = 105 AND c.nome = 'Monitores')
   OR (p.id = 106 AND c.nome = 'Mobiliario')
   OR (p.id = 107 AND c.nome = 'Celulares')
   OR (p.id = 108 AND c.nome = 'Armazenamento')
CREATE (p)-[:PERTENCE_A]->(c);


// ----------------------------------------------------------------------------
// 8. CONFERENCIA DA CARGA
// ----------------------------------------------------------------------------
MATCH (n)
RETURN labels(n)[0] AS tipo_de_no, count(*) AS quantidade
ORDER BY tipo_de_no;

MATCH ()-[r]->()
RETURN type(r) AS tipo_de_aresta, count(*) AS quantidade
ORDER BY tipo_de_aresta;

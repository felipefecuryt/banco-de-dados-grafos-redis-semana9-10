// ============================================================================
// PARTE 3 - TAREFA DE CASA (DESAFIO)
// "Quem comprou o mesmo produto que voce tambem comprou Y"
// Filtragem colaborativa item-usuario-item, sem usar a rede de amizades
// ----------------------------------------------------------------------------
// Pre-requisito: rodar antes o script grafo/01-modelagem-e-insercao.cypher
// Como executar:
//   cypher-shell -u neo4j -p senha123 -f grafo/03-desafio-recomendacao-colaborativa.cypher
// ============================================================================


// ----------------------------------------------------------------------------
// 3.1 CONSULTA DO DESAFIO
//
// O padrao do caminho e:
//   (eu) -> (produto em comum) <- (outro usuario) -> (sugestao)
//
// Observe a seta de volta "<-[:COMPROU]-": ela representa "esse produto tambem
// foi comprado por outra pessoa". Em SQL isso seria um self-join da tabela de
// compras consigo mesma, duas vezes.
//
// Filtros:
//   - outro <> eu .....................: ignora as minhas proprias compras
//   - NOT (eu)-[:COMPROU]->(sugestao) .: nao recomenda o que eu ja tenho
// ----------------------------------------------------------------------------
MATCH (eu:Usuario {id: 1})-[:COMPROU]->(comum:Produto)<-[:COMPROU]-(outro:Usuario)-[:COMPROU]->(sugestao:Produto)
WHERE outro <> eu
  AND NOT (eu)-[:COMPROU]->(sugestao)
RETURN sugestao.id                       AS id_produto,
       sugestao.nome                     AS produto_sugerido,
       sugestao.preco                    AS preco,
       count(DISTINCT outro)             AS usuarios_que_confirmam,
       collect(DISTINCT comum.nome)      AS por_causa_de
ORDER BY usuarios_que_confirmam DESC, preco DESC;

// Resultado esperado para o Felipe (que comprou Mouse Gamer e Teclado Mecanico),
// na ordem do ORDER BY (confirmacoes DESC, depois preco DESC):
//   1. Notebook Gamer -> 3 confirmacoes (Daniela, Eduardo e Helena)
//   2. Monitor 144Hz  -> 1 (Fernanda)
//   3. Cadeira Gamer  -> 1 (Eduardo)
//   4. SSD NVMe 1TB   -> 1 (Fernanda)
//   5. Headset 7.1    -> 1 (Daniela)


// ----------------------------------------------------------------------------
// 3.2 VERSAO COM PONTUACAO (score) EM VEZ DE CONTAGEM SIMPLES
//
// Contar usuarios trata todos os vizinhos como iguais. Aqui cada usuario pesa
// de acordo com quantos produtos ele tem em comum comigo: quem tem gosto mais
// parecido influencia mais a recomendacao.
// ----------------------------------------------------------------------------
MATCH (eu:Usuario {id: 1})-[:COMPROU]->(comum:Produto)<-[:COMPROU]-(outro:Usuario)
WHERE outro <> eu
WITH eu, outro, count(DISTINCT comum) AS similaridade
MATCH (outro)-[:COMPROU]->(sugestao:Produto)
WHERE NOT (eu)-[:COMPROU]->(sugestao)
RETURN sugestao.nome        AS produto_sugerido,
       sum(similaridade)    AS score,
       count(DISTINCT outro) AS vizinhos
ORDER BY score DESC, produto_sugerido
LIMIT 5;


// ----------------------------------------------------------------------------
// 3.3 RECOMENDACAO HIBRIDA: INTERESSE EM COMUM + REDE DE AMIZADES
//
// Junta as duas ideias do trabalho. Um produto sugerido por um amigo de amigo
// E por alguem com o mesmo gosto tem peso maior do que um desconhecido.
// ----------------------------------------------------------------------------
MATCH (eu:Usuario {id: 1})-[:COMPROU]->(:Produto)<-[:COMPROU]-(outro:Usuario)-[:COMPROU]->(sugestao:Produto)
WHERE outro <> eu AND NOT (eu)-[:COMPROU]->(sugestao)

// O WITH DISTINCT garante uma linha por (usuario, sugestao): sem ele, quem tem
// dois produtos em comum comigo seria contado duas vezes no score.
WITH DISTINCT eu, outro, sugestao

// O shortestPath mede a distancia social entre mim e quem comprou o produto.
// Com OPTIONAL MATCH, quem nao esta na minha rede vem com caminho nulo e cai
// no ELSE do CASE (peso 1).
OPTIONAL MATCH caminho = shortestPath( (eu)-[:AMIGO_DE*1..2]->(outro) )
WITH sugestao, outro,
     CASE length(caminho)
       WHEN 1 THEN 3   // amigo direto
       WHEN 2 THEN 2   // amigo de amigo
       ELSE 1          // apenas o mesmo gosto, sem conexao social
     END AS peso
RETURN sugestao.nome             AS produto_sugerido,
       sum(peso)                 AS score_final,
       collect(DISTINCT outro.nome) AS influenciadores
ORDER BY score_final DESC, produto_sugerido
LIMIT 5;


// ----------------------------------------------------------------------------
// 3.4 RECOMENDACAO POR CATEGORIA PREFERIDA
//
// Usa o no :Categoria para sugerir produtos da categoria que eu mais compro e
// que eu ainda nao tenho - util para o usuario novo, que tem poucas compras e
// poucos vizinhos (o problema do "cold start").
// ----------------------------------------------------------------------------
MATCH (eu:Usuario {id: 1})-[:COMPROU]->(:Produto)-[:PERTENCE_A]->(cat:Categoria)
WITH eu, cat, count(*) AS compras_na_categoria
ORDER BY compras_na_categoria DESC
LIMIT 1
MATCH (sugestao:Produto)-[:PERTENCE_A]->(cat)
WHERE NOT (eu)-[:COMPROU]->(sugestao)
RETURN cat.nome        AS categoria_preferida,
       sugestao.nome   AS produto_sugerido,
       sugestao.preco  AS preco
ORDER BY preco;

// ============================================================================
// PARTE 2 - MINI PROJETO: CONSULTA DE RECOMENDACAO NO GRAFO
// "Amigos de amigos que compraram o Produto X"
// ----------------------------------------------------------------------------
// Pre-requisito: rodar antes o script grafo/01-modelagem-e-insercao.cypher
// Como executar:
//   cypher-shell -u neo4j -p senha123 -f grafo/02-recomendacao-amigos-de-amigos.cypher
// ============================================================================


// ----------------------------------------------------------------------------
// 2.1 CONSULTA PRINCIPAL (a resposta do exercicio)
//
// Usuario de referencia: Felipe (id = 1)
// Produto X............: 'Notebook Gamer'
//
// O caminho percorrido no grafo tem 3 saltos:
//   (eu) -> (amigo) -> (amigo_do_amigo) -> (produto)
//
// Os dois filtros do WHERE evitam os falsos positivos classicos:
//   - fof <> eu .......................: eu nao sou recomendacao para mim mesmo
//   - NOT (eu)-[:AMIGO_DE]->(fof) .....: quem ja e meu amigo direto nao e
//                                        "amigo de amigo"
// ----------------------------------------------------------------------------
MATCH (eu:Usuario {id: 1})-[:AMIGO_DE]->(amigo:Usuario)-[:AMIGO_DE]->(fof:Usuario)-[:COMPROU]->(produto:Produto {nome: 'Notebook Gamer'})
WHERE fof <> eu
  AND NOT (eu)-[:AMIGO_DE]->(fof)
RETURN DISTINCT
       fof.id            AS id_usuario,
       fof.nome          AS recomendado_por,
       fof.cidade        AS cidade,
       produto.nome      AS produto,
       produto.preco     AS preco
ORDER BY recomendado_por;

// Resultado esperado: Daniela (id 4) e Eduardo (id 5).
//   - Carlos (3) comprou o Notebook, mas e amigo DIRETO  -> excluido
//   - Gabriel (7) comprou, mas esta a 3 saltos de distancia -> nao alcancado
//   - Helena (8) comprou, mas nao tem nenhuma amizade       -> nao alcancado


// ----------------------------------------------------------------------------
// 2.2 MESMA CONSULTA USANDO SALTOS DE TAMANHO VARIAVEL
//
// *2 significa "exatamente 2 saltos de AMIGO_DE". E uma escrita mais curta e
// permite trocar para *1..3 e ampliar o alcance da recomendacao sem reescrever
// o padrao inteiro.
// ----------------------------------------------------------------------------
MATCH (eu:Usuario {id: 1})-[:AMIGO_DE*2]->(fof:Usuario)-[:COMPROU]->(p:Produto {nome: 'Notebook Gamer'})
WHERE fof <> eu
  AND NOT (eu)-[:AMIGO_DE]->(fof)
RETURN DISTINCT fof.nome AS amigo_de_amigo, p.nome AS produto
ORDER BY amigo_de_amigo;


// ----------------------------------------------------------------------------
// 2.3 VERSAO COM PROVA SOCIAL (quantos amigos em comum levam a cada pessoa)
//
// Aqui o grafo mostra o que o SQL tem dificuldade de entregar: alem de saber
// QUEM recomenda, sabemos POR QUAL CAMINHO a recomendacao chegou.
// ----------------------------------------------------------------------------
MATCH (eu:Usuario {id: 1})-[:AMIGO_DE]->(amigo:Usuario)-[:AMIGO_DE]->(fof:Usuario)-[:COMPROU]->(p:Produto {nome: 'Notebook Gamer'})
WHERE fof <> eu
  AND NOT (eu)-[:AMIGO_DE]->(fof)
RETURN fof.nome                        AS amigo_de_amigo,
       collect(DISTINCT amigo.nome)    AS amigos_em_comum,
       count(DISTINCT amigo)           AS forca_da_conexao
ORDER BY forca_da_conexao DESC, amigo_de_amigo;

// Eduardo aparece com forca 2 (chega por Bruna e por Carlos) e Daniela com
// forca 1 (chega apenas por Bruna) -> Eduardo e a recomendacao mais forte.


// ----------------------------------------------------------------------------
// 2.4 CONSULTA PARAMETRIZADA (como a aplicacao chamaria de verdade)
//
// Em producao nunca se concatena valor dentro da query: usa-se parametro, que
// permite ao Neo4j reaproveitar o plano de execucao em cache.
// No cypher-shell os parametros sao declarados com :param
// ----------------------------------------------------------------------------
:param usuarioId => 1
:param produtoNome => 'Notebook Gamer'

MATCH (eu:Usuario {id: $usuarioId})-[:AMIGO_DE]->(:Usuario)-[:AMIGO_DE]->(fof:Usuario)-[:COMPROU]->(p:Produto {nome: $produtoNome})
WHERE fof <> eu
  AND NOT (eu)-[:AMIGO_DE]->(fof)
RETURN DISTINCT fof.nome AS recomendacao, p.nome AS produto;


// ----------------------------------------------------------------------------
// 2.5 PLANO DE EXECUCAO (para comprovar o custo da travessia)
//
// O PROFILE mostra o numero de "db hits". A consulta parte de UM no (indice
// pelo id), caminha pelas arestas vizinhas e nunca varre as tabelas inteiras
// de usuarios ou de compras - e exatamente esse ponto que a Parte 4 discute.
// ----------------------------------------------------------------------------
PROFILE
MATCH (eu:Usuario {id: 1})-[:AMIGO_DE]->(:Usuario)-[:AMIGO_DE]->(fof:Usuario)-[:COMPROU]->(p:Produto {nome: 'Notebook Gamer'})
WHERE fof <> eu AND NOT (eu)-[:AMIGO_DE]->(fof)
RETURN DISTINCT fof.nome;

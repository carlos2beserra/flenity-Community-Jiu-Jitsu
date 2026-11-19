# Flenity

Plataforma de gestão para academias de Jiu-Jitsu. Reúne gestão de alunos, planos, agenda, check-ins e graduações por faixa e grau.

## Funcionalidades

| Módulo | O que faz |
|---|---|
| **Painel** | Alunos ativos, MRR, recebido x previsto no mês, inadimplência, check-ins, receita de 6 meses e alunos aptos a graduar |
| **Acesso** | Modo recepção: busca rápida do aluno, seleção da aula e validação de acesso (status, plano, atraso acima da carência e limite semanal) |
| **Agenda** | Grade semanal de aulas de Jiu-Jitsu, instrutor e capacidade |
| **Alunos** | Cadastro, planos, mensalidades, histórico de graduação e presenças |
| **Equipe** | Administradores criam acessos de professores no web ou no mobile; professores entram no app como profissionais |
| **Chat mobile** | Conversas diretas em tempo real entre alunos com acesso ao app e equipe da mesma academia |
| **Comunidades mobile** | Um aluno pode vincular perfis de várias academias por convite, alternar entre elas e acessar um mural persistido com publicações, curtidas e comentários |
| **Rede social mobile** | Alunos e equipe no mesmo feed: fotos/vídeos em carrossel, flashes de 24 h, rolas (vídeos curtos), explorar, busca de pessoas, seguir, salvos, comentários, notificações e perfil em grade com foto, bio e faixa. Professores aparecem com o selo **Professor** |
| **Graduações** | Faixa e grau atuais de cada aluno, aulas desde a última promoção x mínimo da faixa, botão de graduar (próximo grau → próxima faixa) |
| **CRM / Leads** | Funil em Kanban (Novo → Contatado → Aula experimental → Matriculado / Perdido) com arrastar e soltar e conversão em aluno |
| **Financeiro** | Contas a receber com filtros (vencidas, em aberto, pagas, mês), baixa com forma de pagamento, cobrança avulsa, lembrete por WhatsApp e geração idempotente das mensalidades do mês |
| **Matrículas** | Contratos aluno × plano, com valor negociado; matricular gera a 1ª cobrança e a faixa inicial |
| **Planos** | Valor, ciclo (mensal/trimestral/semestral/anual) e limite semanal para Jiu-Jitsu |
| **Jiu-Jitsu** | Régua de faixas editável (cor, ordem, aulas mínimas e graus) |

Multi-tenant por academia, com perfis **Administrador**, **Instrutor** e **Recepção**.

## App mobile (Flutter) — aluno e professor

Um único app ([mobile/](mobile/)) com dois perfis, escolhidos na tela de login:

| Aluno | Professor |
|---|---|
| Abas **Início** (flashes + feed), **Pesquisar**, **Criar** (publicação, flash ou rola), **Rolas**, **Faixa X** e **Perfil** | As mesmas abas e a mesma rede social do aluno, com selo **Professor**, e a aba **Descomplicando** |
| Mensagens e notificações no topo do Início; atalhos **Agenda**, **Evolução** e **Mensalidades** no Perfil; **Comunidades** e troca de academia pelo menu ou tocando no @ do Perfil | Atalhos **Aulas**, **Graduações** e **Alunos** no Perfil; chamada pelas aulas de hoje; administrador adiciona professores pelo menu |

Fotos e vídeos ficam em disco (`MEDIA_DIR`, volume `media` no Docker), nunca no banco. O formato é conferido pelos bytes
do arquivo (JPG, PNG, WEBP até 10 MB; MP4/MOV até 60 MB) e a mídia é servida por URLs assinadas (HMAC) que expiram em ~12 h.
**Descomplicando a Faixa X:** aba entre Rolas e Perfil, com o nome e a cor da faixa do aluno. Cada conceito é uma
**videoaula** em **Guarda**, **Passagem**, **Controle** ou **Finalizações**, com player próprio (som, voltar 10 s, câmera lenta 0,5x,
tela cheia na horizontal), resumo opcional e "Marcar como aprendido" com progresso. O aluno vê só videoaulas liberadas, da faixa
atual e das anteriores (revisão); faixas acima ficam fechadas. Professores e administradores (não a recepção) montam a trilha
na aba **Descomplicando**: gravam ou escolhem o vídeo (só vídeo, até 60 MB), reordenam e liberam um a um ou em lote. A API só
libera conceito com vídeo; o "liberar tudo" pula os que ainda não têm vídeo. A **trilha sugerida** de cada faixa entra como rascunho
para o professor gravar os vídeos. A migração `20261120120000_belt_tracks` só adiciona tabelas; o seed cria a sugestão em rascunho.

**Entrar com biometria:** no login (ou no menu do Perfil) o aluno ou professor pode ativar digital/Face ID. A API emite
uma credencial de aparelho (`POST /auth/device-credentials`); o app guarda o segredo no armazenamento seguro e só o envia
(`POST /auth/device-login`) depois da biometria. O banco guarda apenas o hash, a credencial expira em 90 dias sem uso,
pode ser revogada (`DELETE /auth/device-credentials/:id`) e é apagada quando o aluno troca a senha. A senha nunca fica no celular.

A migração `20261117120000_social_network` só adiciona tabelas e colunas. A `20261118120000_community_members` cria o perfil social
(`CommunityMember`, de um aluno **ou** de alguém da equipe) e move para ele, sem perder dados, posts, curtidas, seguidores,
flashes, notificações, bio e foto. As rotas `/student/community/*` aceitam token de aluno e de equipe; convites e troca de
academia (`/student/communities/*`) continuam só para alunos.

Na agenda mobile, o aluno pode registrar presença em diferentes aulas de Jiu-Jitsu dentro da janela de check-in. Todas as presenças ficam no histórico; para a graduação, conta no máximo um check-in por dia.

O acesso do aluno é liberado pela recepção no sistema web (ficha do aluno → **Liberar app**), que gera uma
senha provisória. Para convidar um aluno para outra academia, a equipe abre a ficha dele e usa **Convidar para comunidade**;
o link é compartilhado manualmente, expira em 14 dias e só pode ser aceito no app com o mesmo e-mail. Tokens de aluno só
acessam as rotas `/student/*` e `/chat/*`, escopadas ao perfil e à academia selecionados.

A migração `20261111100000_jiujitsu_only` atualiza o banco para operar exclusivamente com Jiu-Jitsu. Aplique-a somente após confirmar um backup do banco.

```bash
make mobile-run                                   # Chrome/desktop/aparelho conectado
make mobile-run API_URL=http://10.0.2.2:8080/api  # emulador Android
make mobile-apk API_URL=https://suaacademia.com/api
make mobile-test
```

Contas demo: aluno **aluno@flenity.com / combate123** · professor **instrutor1@flenity.com / combate123**.

## Stack

- **API**: NestJS 11, Prisma 6, PostgreSQL 17, JWT, class-validator, rate limiting (`@nestjs/throttler`)
- **Web**: React 19, Vite 6, TanStack Query, React Router
- **Testes**: Jest (regras de negócio da API) e Vitest + Testing Library (web)

Toda resposta da API segue `{ "success": boolean, "data": ..., "error": { code, message, details? } | null }`.
Listagens são paginadas (`page`, `pageSize`, `search`). Campos desconhecidos são rejeitados.

## Como rodar (Docker)

```bash
make up      # cria o .env com segredos aleatórios, builda e sobe banco + API + web
make seed    # dados de demonstração
```

Acesse **http://localhost:8080**. Rode `make help` para ver todos os comandos (`logs`, `ps`, `down`, `migrate`,
`db-shell`, `test`, `clean`…).

| Serviço | Imagem | Porta |
|---|---|---|
| `web` | nginx servindo o build do React + proxy de `/api` | `8080` (`WEB_PORT`) |
| `api` | NestJS; aplica `prisma migrate deploy` ao iniciar | interna `3000` |
| `postgres` | postgres:17, volume `pgdata` | `127.0.0.1:5433` (`DB_PORT`) |

## Como rodar (desenvolvimento local)

```bash
make dev-db                 # só o Postgres no Docker
cp api/.env.example api/.env  # ajuste DATABASE_URL com a senha do .env e um JWT_SECRET
make install
make dev-api                # http://localhost:3000/api
make dev-web                # http://localhost:5173 (outro terminal)
```

Login de demonstração: **admin@flenity.com / combate123**
(também existem `recepcao@flenity.com` e `instrutor1@flenity.com` com a mesma senha).

> ⚠️ O seed **apaga e recria** a academia de demonstração.

## Testes

```bash
cd api && npm test   # regras de cobrança, check-in, graduação e fuso horário
cd web && npm test   # formatação, faixa, gráfico
```

## Estrutura

```
api/
  prisma/schema.prisma        modelo de dados
  src/domain/                 regras de negócio puras (testadas, sem framework)
    billing.ts                vencimentos por ciclo, dias de atraso
    checkin-policy.ts         liberação/bloqueio de acesso
    graduation.ts             próxima graduação e aptidão
    dates.ts                  datas e fuso (America/Sao_Paulo, via APP_TIMEZONE)
  src/common/                 auth/roles, envelope de resposta, paginação, Prisma
  src/modules/<módulo>/       dto + service + controller por recurso
web/
  src/pages/                  telas
  src/components/             UI, faixa (BeltBadge), gráfico de barras, layout
  src/lib/                    cliente da API, auth, formatação, tipos
```

## Endpoints principais

`POST /auth/register` · `POST /auth/login` · `GET /auth/me` · `GET|POST /users`
`GET|POST|PATCH|DELETE /students` · `GET|POST /modalities` · `PUT /modalities/:id/belts`
`GET|POST|PATCH /plans` · `GET|POST /memberships` · `POST /memberships/:id/cancel`
`GET|POST /invoices` · `POST /invoices/generate` · `POST /invoices/:id/pay|cancel`
`GET|POST|PATCH|DELETE /classes` · `GET /classes/today`
`GET|POST|DELETE /check-ins` · `GET /graduations` · `POST /graduations/promote`
`GET|POST|PATCH /leads` · `POST /leads/:id/convert` · `GET /dashboard` · `GET /dashboard/birthdays`
`GET /student/communities` · `POST /student/communities/invitations/accept` · `POST /student/communities/:studentId/switch`
`GET|POST /student/community/posts` (paginado; `scope=all|following`, `kind=POST|REEL`, `authorId`) · `GET|DELETE /student/community/posts/:postId`
`POST /student/community/posts/:postId/like|save` · `GET|POST /student/community/posts/:postId/comments` · `DELETE …/comments/:commentId`
`POST /student/community/media` (multipart `file`) · `GET /media/:id?exp&sig` · `GET /student/community/explore|saved`
`GET /student/community/people[?search]` · `GET /student/community/people/me|:id` · `GET …/people/:id/followers|following` · `POST …/people/:id/follow`
`PATCH /student/community/profile` · `GET|POST /student/community/stories` (flashes) · `POST …/stories/:id/view` · `GET …/stories/:id/viewers` · `DELETE …/stories/:id`
`GET /student/community/notifications` · `GET …/notifications/unread-count` · `POST …/notifications/read`
`GET /student/tracks[?beltId]` · `POST|DELETE /student/tracks/lessons/:id/complete` (aluno)
`GET /tracks[?beltId]` · `POST /tracks/lessons` · `PATCH|DELETE /tracks/lessons/:id` · `POST /tracks/lessons/:id/move` · `POST /tracks/publish` · `POST /tracks/starter` (professor/admin)

## Próximos passos sugeridos

- App do aluno (agenda, check-in por QR Code, histórico de faixa)
- Integração de pagamento (Pix/cartão recorrente) e emissão de boletos
- Integração com catraca/biometria
- Exames de graduação com certificado
- Rotina agendada para gerar mensalidades e lembretes automaticamente
- Testes de integração da API com banco (Testcontainers) e E2E com Playwright
# flenity-Community-Jiu-Jitsu

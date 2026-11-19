# Flenity

App do aluno e do professor - Flenity

## Comunidade de Jiu-Jitsu

O feed e o mural da aba **Comunidade** são dedicados ao Jiu-Jitsu, com publicações sobre técnica, treinos, graduações e open mat, além de curtidas e comentários.

## Comunidades

Um aluno pode participar de comunidades em mais de uma academia. A equipe gera o convite na ficha do aluno no sistema web e
compartilha o link manualmente. No app, cole o link ou código em **Comunidade**; o convite expira em 14 dias e precisa
corresponder ao e-mail da conta. A academia selecionada define os dados exibidos em agenda, mensalidades, chat e mural.
As migrações `20261109170000_chat_messages` e `20261109183000_communities` devem ser aplicadas pela API.

## Perfil do aluno

O perfil reúne resumo de atividades, próxima aula/check-in, evolução e graduações do Jiu-Jitsu, dados pessoais, atividade recente,
segurança da conta, agenda e mensalidades.

Na agenda, o aluno pode fazer check-in em várias aulas diferentes de Jiu-Jitsu dentro da janela liberada. Todas as presenças ficam registradas; para a graduação, vale no máximo um check-in por dia.

Administradores também podem criar acessos de professores na aba **Perfil**, informando nome, e-mail e senha inicial. A criação fica restrita ao perfil ADMIN também na API.

## Chat

O chat salva conversas e mensagens na API e entrega mensagens novas em tempo real por Socket.IO. Alunos podem conversar com a equipe da própria academia; a equipe pode iniciar conversas com alunos ativos que tenham acesso ao app. A migração `20261109170000_chat_messages` deve ser aplicada pela API antes de usar a aba.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

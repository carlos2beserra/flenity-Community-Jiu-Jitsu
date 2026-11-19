# API de Jiu-Jitsu

As rotas usam o prefixo `/api` e exigem autenticação de equipe. Respostas bem-sucedidas seguem o envelope `{ "success": true, "data": ..., "error": null }`.

## Jiu-Jitsu e faixas

- `GET /api/modalities` — lista a modalidade Jiu-Jitsu da academia autenticada e suas faixas, em ordem.
- `POST /api/modalities` — configura Jiu-Jitsu para a academia. Disponível para administradores; não aceita outras modalidades nem duplicatas.
- `PUT /api/modalities/:id/belts` — substitui a régua de faixas. Disponível para administradores e instrutores. É necessário enviar ao menos uma faixa.
- `DELETE /api/modalities/:id` — não permitido: Jiu-Jitsu é obrigatório.

Exemplo de corpo para criar a modalidade:

```json
{
  "name": "Jiu-Jitsu",
  "belts": [{
    "name": "Branca",
    "color": "#f5f5f5",
    "order": 0,
    "minClasses": 40,
    "maxDegrees": 4
  }]
}
```

Para atualizar as faixas, envie `{ "belts": [...] }` para a rota `PUT`. Cada faixa aceita `name`, `order`, `color`, `minClasses` e `maxDegrees`; a ordem deve ser única.

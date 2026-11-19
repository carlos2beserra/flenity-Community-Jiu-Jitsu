import { useState } from 'react';
import { useSearchParams } from 'react-router-dom';

export function CommunityInvitePage() {
  const [params] = useSearchParams();
  const [copied, setCopied] = useState(false);
  const [copyError, setCopyError] = useState(false);
  const hash = new URLSearchParams(window.location.hash.slice(1));
  const token = params.get('token') ?? hash.get('token') ?? '';

  const copyToken = async () => {
    try {
      await navigator.clipboard.writeText(token);
      setCopied(true);
      setCopyError(false);
    } catch {
      setCopyError(true);
    }
  };

  return (
    <main>
      <section className="card" style={{ maxWidth: 520, margin: '10vh auto', padding: 32 }}>
        <p className="kicker">FLENITY · COMUNIDADE</p>
        <h1>Seu próximo treino começa aqui.</h1>
        {token ? <>
          <p>Abra o app Flenity, entre em <strong>Comunidade</strong> e cole este convite para participar da academia.</p>
          <label className="field">
            <span>Código do convite</span>
            <input className="input" readOnly value={token} onFocus={(event) => event.currentTarget.select()} />
          </label>
          <button className="btn btn-primary" onClick={copyToken}>
            {copied ? 'Código copiado' : 'Copiar código'}
          </button>
          {copyError && <p className="alert alert-bad">Não foi possível copiar. Selecione e copie o código manualmente.</p>}
          <p className="muted" style={{ fontSize: 13 }}>Este convite é pessoal e expira em 14 dias. Entre no app com o mesmo e-mail que recebeu o link.</p>
        </> : <p>Este link de convite não contém um código válido. Peça à academia para gerar um novo.</p>}
      </section>
    </main>
  );
}

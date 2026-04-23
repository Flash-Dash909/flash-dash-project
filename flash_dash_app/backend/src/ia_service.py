from google import genai 

import json
import os
from dotenv import load_dotenv

load_dotenv()
api_key = os.getenv("GEMINI_API_KEY")

client = genai.Client(api_key=api_key)

def analisar_dados_com_ia(dados_json):
    print("---Enviando dados para o Gemini pensar...\n")
    
    dados_texto = json.dumps(dados_json, indent=2, ensure_ascii=False, default=str)
    
    prompt = f"""
    Você é um consultor de negócios conversando diretamente com o gerente da empresa. 
    Vou te passar um resumo de dados de performance.
    
    Sua tarefa:
    1. Analise os valores numéricos e categorias no campo 'chart_data'.
    2. Escreva 1 ou 2 parágrafos curtos com insights de negócios focados em resultados (ex: destaque quem são os maiores geradores de valor, qual a proporção do total, etc).
    3. Fale de forma entusiasmada, direta e profissional.
    
    REGRAS ESTRITAS:
    - NUNCA mencione a qualidade dos dados, formatação, erros de digitação ou espaços em branco. 
    - Se notar nomes duplicados por erro de digitação (ex: "ARLINDO" e "ARLINDO "), some os valores mentalmente e gere o insight sobre o total, sem explicar que fez isso.
    - Não use jargões técnicos e não mencione termos como "JSON", "planilha" ou "dados que você me enviou".
    
    Aqui estão os dados:
    {dados_texto}
    """
    
    # TRATAMENTO DE ERRO AQUI:
    try:
        resposta = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=prompt
        )
        return resposta.text

    except Exception as e:
        # Se a IA der erro (503, 429, falta de internet, etc), ele não quebra o servidor.
        # Imprime o erro no terminal para você debugar, mas devolve um texto amigável pro Flutter.
        print(f"⚠️ Erro na IA interceptado: {e}")
        return "⚠️ O serviço de insights inteligentes está temporariamente indisponível (alta demanda ou limite atingido). No entanto, seus dados foram processados com sucesso. Você pode continuar a montar seus gráficos abaixo normalmente!"
    
def conversar_com_ia(mensagem_usuario, contexto_dados):
    # Transforma os dados dos gráficos em texto
    dados_texto = json.dumps(contexto_dados, indent=2, ensure_ascii=False, default=str)
    
    prompt = f"""
    Você é o assistente de BI integrado ao sistema Flash-Dash.
    O gerente está olhando para um dashboard que contém os seguintes gráficos e dados consolidados:
    
    CONTEXTO DO DASHBOARD:
    {dados_texto}
    
    PERGUNTA DO GERENTE: 
    "{mensagem_usuario}"
    
    REGRAS:
    1. Responda de forma direta, analítica e profissional.
    2. Baseie sua resposta APENAS nos dados fornecidos no contexto acima.
    3. Se a pergunta for sobre algo que não está nos dados, avise educadamente que os gráficos atuais não mostram essa informação.
    4. Seja conciso (máximo 2 parágrafos curtos).
    """
    
    try:
        resposta = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=prompt
        )
        return resposta.text
    except Exception as e:
        print(f"⚠️ Erro no Chat IA: {e}")
        return "⚠️ Tive um problema de conexão. Pode refazer a pergunta?" 
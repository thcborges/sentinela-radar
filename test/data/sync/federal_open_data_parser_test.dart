import 'package:flutter_test/flutter_test.dart';
import 'package:sentinela/core/models/poi_model.dart';
import 'package:sentinela/data/sync/federal_open_data_parser.dart';

void main() {
  group('FederalOpenDataParser (DNIT PNCV e ANTT Concessões)', () {
    test('deve parsear JSON CKAN do DNIT PNCV convertendo em PoiPoints', () {
      const dnitJson = '''
      {
        "help": "https://dados.gov.br",
        "success": true,
        "result": {
          "records": [
            {
              "_id": 101,
              "uf": "SP",
              "rodovia": "BR-116",
              "km": "230.5",
              "municipio": "São Paulo",
              "tipo_equipamento": "Radar Fixo",
              "velocidade_regulamentada": 60,
              "latitude": -23.5505,
              "longitude": -46.6333,
              "sentido": "Crescente"
            },
            {
              "_id": 102,
              "uf": "RJ",
              "rodovia": "BR-101",
              "km": "115.0",
              "municipio": "Niterói",
              "tipo_equipamento": "Redutor Eletrônico",
              "velocidade_regulamentada": 40,
              "latitude": -22.8808,
              "longitude": -43.1043,
              "sentido": "Ambos"
            },
            {
              "_id": 103,
              "uf": "MG",
              "rodovia": "BR-381",
              "km": "450.0",
              "municipio": "Betim",
              "tipo_equipamento": "Controlador Eletrônico",
              "velocidade_regulamentada": 80,
              "latitude": -19.9678,
              "longitude": -44.1985,
              "sentido": "Decrescente"
            }
          ]
        }
      }
      ''';

      final pois = FederalOpenDataParser.parseDnitJson(dnitJson);

      expect(pois.length, 3);

      expect(pois[0].id, 101);
      expect(pois[0].type, PoiType.fixedRadar);
      expect(pois[0].speedLimit, 60);
      expect(pois[0].latitude, -23.5505);
      expect(pois[0].longitude, -46.6333);
      expect(pois[0].roadName, 'BR-116 km 230.5');
      expect(pois[0].city, 'São Paulo');
      expect(pois[0].state, 'SP');
      expect(pois[0].source, 'DNIT_PNCV');

      expect(pois[1].id, 102);
      expect(pois[1].type, PoiType.electronicSpeedBump);
      expect(pois[1].speedLimit, 40);
      expect(pois[1].toleranceAngle, 180.0); // Ambos os sentidos

      expect(pois[2].id, 103);
      expect(pois[2].type, PoiType.fixedRadar);
      expect(pois[2].speedLimit, 80);
    });

    test('deve parsear CSV do DNIT PNCV com tratamento de linhas e campos vazios', () {
      const dnitCsv = '''id,uf,rodovia,km,municipio,tipo_equipamento,velocidade_regulamentada,latitude,longitude,sentido
201,MG,BR-381,450.2,Belo Horizonte,Radar Fixo,80,-19.9167,-43.9345,Decrescente
202,PR,BR-277,100.0,Curitiba,Lombada Eletrônica,50,-25.4284,-49.2733,Ambos
''';

      final pois = FederalOpenDataParser.parseDnitCsv(dnitCsv);

      expect(pois.length, 2);
      expect(pois[0].id, 201);
      expect(pois[0].type, PoiType.fixedRadar);
      expect(pois[0].speedLimit, 80);
      expect(pois[0].roadName, 'BR-381 km 450.2');

      expect(pois[1].id, 202);
      expect(pois[1].type, PoiType.electronicSpeedBump);
      expect(pois[1].speedLimit, 50);
      expect(pois[1].state, 'PR');
    });

    test('BUG REGRESSÃO: deve parsear CSV oficial do DNIT PNCV com coluna Coordenadas (Lat/Long) e siglas REV/CEV/CEM', () {
      const officialDnitCsv = '''Código Identificação;UF;Rodovia;Km;Município;Faixas;Tipo;Marca / Modelo;Edital / Lote (Operadora);Início Operação;Coordenadas (Lat/Long);Cód. ET;Cód. EV
ACB22010002;AC;364;124,4;RIO BRANCO;P-C-1, P-C-2;REV;Vizentec / DTV 102;168.2016 / 10;10/08/2022;-10,011417 / -67,794678;ET.1912.AC0001;EV.1910.AC0016
SPB18080001;SP;116;230;SAO PAULO;P-C-1;CEV;Consilux;168.2016 / 14;16/01/2019;-23,550520 / -46,633308;ET.1806;EV.1805
RJB18080002;RJ;101;15;NITEROI;P-C-1;CEM;Consilux;168.2016 / 14;16/01/2019;-22,880000 / -43,120000;ET.1806;EV.1805
''';

      final pois = FederalOpenDataParser.parseDnitCsv(officialDnitCsv);

      expect(pois.length, 3);
      // REV -> electronicSpeedBump
      expect(pois[0].type, PoiType.electronicSpeedBump);
      expect(pois[0].latitude, closeTo(-10.011417, 0.0001));
      expect(pois[0].longitude, closeTo(-67.794678, 0.0001));
      expect(pois[0].state, 'AC');
      expect(pois[0].city, 'RIO BRANCO');
      expect(pois[0].roadName, 'BR-364 km 124.4');

      // CEV -> fixedRadar
      expect(pois[1].type, PoiType.fixedRadar);
      expect(pois[1].latitude, closeTo(-23.550520, 0.0001));
      expect(pois[1].longitude, closeTo(-46.633308, 0.0001));
      expect(pois[1].state, 'SP');

      // CEM -> trafficLightRadar
      expect(pois[2].type, PoiType.trafficLightRadar);
      expect(pois[2].latitude, closeTo(-22.880000, 0.0001));
      expect(pois[2].longitude, closeTo(-43.120000, 0.0001));
      expect(pois[2].state, 'RJ');
    });

    test('deve parsear JSON CKAN da ANTT de praças e pórticos Free Flow', () {
      const anttJson = '''
      {
        "success": true,
        "result": {
          "records": [
            {
              "id": 501,
              "concessionaria": "CCR NovaDutra",
              "rodovia": "BR-116",
              "km": "180.0",
              "municipio": "Guarulhos",
              "uf": "SP",
              "tipo_praca": "Convencional",
              "tarifa_carro": 15.20,
              "latitude": -23.4628,
              "longitude": -46.5333
            },
            {
              "id": 502,
              "concessionaria": "EcoRioMinas",
              "rodovia": "BR-101",
              "km": "12.5",
              "municipio": "Paraty",
              "uf": "RJ",
              "tipo_praca": "Free Flow",
              "tarifa_carro": 4.60,
              "latitude": -23.2200,
              "longitude": -44.7200
            }
          ]
        }
      }
      ''';

      final pois = FederalOpenDataParser.parseAnttJson(anttJson);

      expect(pois.length, 2);

      expect(pois[0].id, 501);
      expect(pois[0].type, PoiType.tollBooth);
      expect(pois[0].tollFeeCar, 15.20);
      expect(pois[0].operator, 'CCR NovaDutra');
      expect(pois[0].roadName, 'BR-116 km 180.0');
      expect(pois[0].city, 'Guarulhos');
      expect(pois[0].source, 'ANTT');

      expect(pois[1].id, 502);
      expect(pois[1].type, PoiType.freeFlowToll);
      expect(pois[1].tollFeeCar, 4.60);
      expect(pois[1].operator, 'EcoRioMinas');
      expect(pois[1].source, 'ANTT');
    });

    test('deve parsear CSV da ANTT com sucesso', () {
      const anttCsv = '''id,concessionaria,rodovia,km,municipio,uf,tipo_praca,tarifa_carro,latitude,longitude
601,Autovias,BR-050,85.0,Uberaba,MG,Convencional,8.90,-19.7472,-47.9392
602,Viasul,BR-101,50.0,Torres,RS,Pórtico Free Flow,5.20,-29.3350,-49.7269
''';

      final pois = FederalOpenDataParser.parseAnttCsv(anttCsv);

      expect(pois.length, 2);
      expect(pois[0].id, 601);
      expect(pois[0].type, PoiType.tollBooth);
      expect(pois[0].tollFeeCar, 8.90);
      expect(pois[0].operator, 'Autovias');

      expect(pois[1].id, 602);
      expect(pois[1].type, PoiType.freeFlowToll);
      expect(pois[1].tollFeeCar, 5.20);
    });

    test('deve retornar lista vazia ou ignorar registros inválidos sem falhar', () {
      expect(FederalOpenDataParser.parseDnitJson('{"invalid": true}'), isEmpty);
      expect(FederalOpenDataParser.parseDnitCsv(''), isEmpty);
      expect(FederalOpenDataParser.parseAnttJson('{}'), isEmpty);
      expect(FederalOpenDataParser.parseAnttCsv(''), isEmpty);
    });

    test('BUG #34 REGRESSÃO: deve parsear CSV do DNIT com coordenadas e velocidades formatadas em PT-BR (vírgula decimal)', () {
      const dnitCsvCommasInQuotes = '''id,uf,rodovia,km,municipio,tipo_equipamento,velocidade_regulamentada,latitude,longitude,sentido
301,MG,BR-381,450.2,Belo Horizonte,Radar Fixo,"60,0","-19,9167","-43,9345",Decrescente
''';
      final poisQuotes = FederalOpenDataParser.parseDnitCsv(dnitCsvCommasInQuotes);
      expect(poisQuotes.length, 1);
      expect(poisQuotes[0].id, 301);
      expect(poisQuotes[0].latitude, -19.9167);
      expect(poisQuotes[0].longitude, -43.9345);
      expect(poisQuotes[0].speedLimit, 60);

      const dnitCsvSemicolons = '''id;uf;rodovia;km;municipio;tipo_equipamento;velocidade_regulamentada;latitude;longitude;sentido
302;PR;BR-277;100,0;Curitiba;Lombada Eletrônica;50,0;-25,4284;-49,2733;Ambos
''';
      final poisSemicolons = FederalOpenDataParser.parseDnitCsv(dnitCsvSemicolons);
      expect(poisSemicolons.length, 1);
      expect(poisSemicolons[0].id, 302);
      expect(poisSemicolons[0].latitude, -25.4284);
      expect(poisSemicolons[0].longitude, -49.2733);
      expect(poisSemicolons[0].speedLimit, 50);
      expect(poisSemicolons[0].type, PoiType.electronicSpeedBump);
    });

    test('BUG #34 REGRESSÃO: deve parsear CSV da ANTT com coordenadas e tarifas com vírgula decimal e ponto-e-vírgula', () {
      const anttCsv = '''id;concessionaria;rodovia;km;municipio;uf;tipo_praca;tarifa_carro;latitude;longitude
701;Autovias;BR-050;85,0;Uberaba;MG;Convencional;8,90;-19,7472;-47,9392
''';
      final pois = FederalOpenDataParser.parseAnttCsv(anttCsv);
      expect(pois.length, 1);
      expect(pois[0].id, 701);
      expect(pois[0].latitude, -19.7472);
      expect(pois[0].longitude, -47.9392);
      expect(pois[0].tollFeeCar, 8.90);
    });

    test('BUG #34 REGRESSÃO: deve parsear JSON CKAN do DNIT com coordenadas e velocidades em formato String com vírgula', () {
      const dnitJson = '''
      {
        "success": true,
        "result": {
          "records": [
            {
              "_id": 401,
              "uf": "SP",
              "rodovia": "BR-116",
              "km": "230,5",
              "municipio": "São Paulo",
              "tipo_equipamento": "Radar Fixo",
              "velocidade_regulamentada": "60,0",
              "latitude": "-23,5505",
              "longitude": "-46,6333",
              "sentido": "Crescente"
            }
          ]
        }
      }
      ''';

      final pois = FederalOpenDataParser.parseDnitJson(dnitJson);
      expect(pois.length, 1);
      expect(pois[0].id, 401);
      expect(pois[0].latitude, -23.5505);
      expect(pois[0].longitude, -46.6333);
      expect(pois[0].speedLimit, 60);
    });

    test('BUG #34 REGRESSÃO: deve parsear JSON CKAN da ANTT com coordenadas e tarifas em String com vírgula', () {
      const anttJson = '''
      {
        "success": true,
        "result": {
          "records": [
            {
              "id": "801",
              "concessionaria": "CCR RioSP",
              "rodovia": "BR-116",
              "km": "180,0",
              "municipio": "Guarulhos",
              "uf": "SP",
              "tipo_praca": "Convencional",
              "tarifa_carro": "15,20",
              "latitude": "-23,4628",
              "longitude": "-46,5333"
            }
          ]
        }
      }
      ''';

      final pois = FederalOpenDataParser.parseAnttJson(anttJson);
      expect(pois.length, 1);
      expect(pois[0].id, 801);
      expect(pois[0].latitude, -23.4628);
      expect(pois[0].longitude, -46.5333);
      expect(pois[0].tollFeeCar, 15.20);
    });
  });
}

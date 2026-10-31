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
  });
}
